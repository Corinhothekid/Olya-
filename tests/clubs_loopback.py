"""Exercise two Lua Clubs sessions against a temporary relay via real HTTP.

Run with Python 3 and liblua5.4 from the repository root. Optional arguments
select the Codea bundle and relay source directory.
"""

import argparse
import ctypes as lua
from http.client import HTTPConnection
import json
import os
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
from threading import Thread


def literal(value):
    if isinstance(value, dict):
        return "{" + ",".join(f"[{literal(key)}]={literal(child)}" for key, child in value.items()) + "}"
    if isinstance(value, list):
        return "{" + ",".join(map(literal, value)) + "}"
    if isinstance(value, str):
        return '"' + "".join(f"\\{byte:03d}" for byte in value.encode("utf-8")) + '"'
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return str(value).lower()
    return str(value)


def run_case(port, relay=None):
    lib = lua.CDLL("liblua5.4.so.0")
    pointer, integer = lua.c_void_p, lua.c_longlong
    callback = lua.CFUNCTYPE(lua.c_int, pointer)
    lib.luaL_newstate.restype = pointer
    lib.luaL_openlibs.argtypes = [pointer]
    lib.luaL_loadfilex.argtypes = [pointer, lua.c_char_p, lua.c_char_p]
    lib.lua_pcallk.argtypes = [pointer, lua.c_int, lua.c_int, lua.c_int, integer, pointer]
    lib.lua_tolstring.argtypes = [pointer, lua.c_int, pointer]
    lib.lua_tolstring.restype = lua.c_char_p
    lib.lua_pushlstring.argtypes = [pointer, lua.c_char_p, lua.c_size_t]
    lib.lua_pushlstring.restype = pointer
    lib.lua_pushinteger.argtypes = [pointer, integer]
    lib.lua_pushcclosure.argtypes = [pointer, callback, lua.c_int]
    lib.lua_setglobal.argtypes = [pointer, lua.c_char_p]
    lib.lua_close.argtypes = [pointer]

    errors = []

    @callback
    def post(state):
        try:
            path, body, auth = (lib.lua_tolstring(state, index, None) for index in (1, 2, 3))
            path = path.decode("ascii")
            if not path.startswith("/v1/"):
                raise ValueError("Only the relay API is accepted by this test bridge")
            if relay:
                from relay import RelayError
                try:
                    result = relay.handle(path.removeprefix("/v1/"), json.loads(body), auth.decode("ascii"))
                    status = 200
                except RelayError as error:
                    result, status = {"message": str(error)}, error.status
            else:
                headers = {"Content-Type": "application/json"}
                if auth:
                    headers["Authorization"] = auth.decode("ascii")
                conn = HTTPConnection("127.0.0.1", port, timeout=4)
                try:
                    conn.request("POST", path, body, headers)
                    response = conn.getresponse()
                    status, result = response.status, json.loads(response.read())
                finally:
                    conn.close()
            value = literal(result).encode("utf-8")
        except Exception as error:
            # Report bridge failures after the protected Lua call returns.
            errors.append(error)
            status, value = 503, b"{}"
        lib.lua_pushinteger(state, status)
        lib.lua_pushlstring(state, value, len(value))
        return 2

    state = lib.luaL_newstate()
    try:
        lib.luaL_openlibs(state)
        lib.lua_pushcclosure(state, post, 0)
        lib.lua_setglobal(state, b"relayTestPost")
        script = Path(__file__).with_suffix(".lua")
        status = lib.luaL_loadfilex(state, os.fsencode(script), None)
        if status == 0:
            status = lib.lua_pcallk(state, 0, 0, 0, 0, None)
        if errors:
            raise RuntimeError("The relay test bridge failed") from errors[0]
        if status:
            raw = lib.lua_tolstring(state, -1, None)
            raise RuntimeError(raw.decode("utf-8") if raw else "Lua raised an unspecified error")
    finally:
        lib.lua_close(state)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path, default=Path("PolyLax.codea"), nargs="?")
    parser.add_argument("relay", type=Path, default=Path("server/clubs"), nargs="?")
    parser.add_argument("--direct", action="store_true", help="Use the relay without TCP in restricted test sandboxes")
    args = parser.parse_args()
    os.environ["POLYLAX_TEST_PROJECT"] = str(args.project.resolve())
    os.environ["POLYLAX_TEST_CHECKS"] = str(Path(__file__).parent.resolve()) + "/"
    sys.path.insert(0, str(args.relay.resolve()))
    from relay import Relay, Server

    with TemporaryDirectory(prefix="polylax-loopback-") as directory:
        database = Path(directory) / "rooms.sqlite3"
        if args.direct:
            os.environ["POLYLAX_RELAY_TEST_URL"] = "http://127.0.0.1:8765"
            run_case(8765, relay=Relay(database))
            print("Relay persistence and Lua integration passed in direct-call mode")
            return
        with Server(("127.0.0.1", 0), database) as server:
            runner = Thread(target=server.serve_forever, kwargs={"poll_interval": .02})
            runner.start()
            try:
                os.environ["POLYLAX_RELAY_TEST_URL"] = f"http://127.0.0.1:{server.server_port}"
                run_case(server.server_port)
                print("Relay persistence and Lua integration passed over TCP loopback")
            finally:
                server.shutdown()
                runner.join()


if __name__ == "__main__":
    main()
