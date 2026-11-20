// Procedural Babylon rig derived from the PolyLax Craft player's proportions and kit.
const LacrosseView = (() => {
    const V = (x = 0, y = 0, z = 0) => new BABYLON.Vector3(x, y, z);
    const C = hex => BABYLON.Color3.FromHexString(hex);
    const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
    const lerp = (a, b, t) => a + (b - a) * t;
    const white = "#e8f2f1";
    const dark = "#0d1625";
    const silver = "#a1afbb";
    const palettes = [
        { jersey: "#7653b4", trim: "#c5b0fc", shorts: "#342457", helmet: "#271a43", number: "#fff9fe" },
        { jersey: "#ee7739", trim: "#fbc58a", shorts: "#302840", helmet: "#2b253f", number: "#fff4df" }
    ];
    const skins = ["#d89e77", "#ac7153", "#e3b793", "#805043", "#b98365"];

    class Geometry {
        constructor() {
            this.positions = [];
            this.normals = [];
            this.colors = [];
            this.indices = [];
            this.tints = new Map();
        }

        color(name) {
            if (!this.tints.has(name)) this.tints.set(name, C(name));
            return this.tints.get(name);
        }

        tri(a, b, c, tint) {
            const start = this.positions.length / 3;
            const normal = BABYLON.Vector3.Cross(b.subtract(a), c.subtract(a)).normalize();
            const { r, g, b: blue } = this.color(tint);
            for (const point of [a, b, c]) {
                this.positions.push(point.x, point.y, point.z);
                this.normals.push(normal.x, normal.y, normal.z);
                this.colors.push(r, g, blue, 1);
            }
            this.indices.push(start, start + 1, start + 2);
        }

        quad(a, b, c, d, tint) {
            this.tri(a, b, c, tint);
            this.tri(a, c, d, tint);
        }

        loft(rings, sides, tint) {
            const rows = rings.map(([y, rx, rz, z = 0, x = 0]) => Array.from({ length: sides }, (_, i) => {
                const angle = (i + .5) * Math.PI * 2 / sides;
                return V(x + Math.cos(angle) * rx, y, z + Math.sin(angle) * rz);
            }));
            for (let i = 0; i < sides; i++) {
                const j = (i + 1) % sides;
                for (let k = 1; k < rows.length; k++) {
                    this.quad(rows[k - 1][i], rows[k][i], rows[k][j], rows[k - 1][j], tint);
                }
                const first = rings[0], last = rings.at(-1);
                this.tri(V(first[4] || 0, first[0], first[3] || 0), rows[0][i], rows[0][j], tint);
                this.tri(V(last[4] || 0, last[0], last[3] || 0), rows.at(-1)[j], rows.at(-1)[i], tint);
            }
        }

        box(x, y, z, width, height, depth, tint) {
            this.loft([[y - height / 2, width / Math.SQRT2, depth / Math.SQRT2, z, x],
                [y + height / 2, width / Math.SQRT2, depth / Math.SQRT2, z, x]], 4, tint);
        }

        rail(points, radius, tint, sides = 5) {
            for (let k = 1; k < points.length; k++) {
                const a = points[k - 1], b = points[k];
                const direction = b.subtract(a).normalize();
                const tangent = BABYLON.Vector3.Cross(direction, Math.abs(direction.y) > .9 ? V(1) : V(0, 1)).normalize();
                const bitangent = BABYLON.Vector3.Cross(direction, tangent);
                const ring = Array.from({ length: sides }, (_, i) => {
                    const angle = i * 2 * Math.PI / sides;
                    return tangent.scale(Math.cos(angle) * radius).add(bitangent.scale(Math.sin(angle) * radius));
                });
                for (let i = 0; i < sides; i++) {
                    const j = (i + 1) % sides;
                    this.quad(a.add(ring[i]), a.add(ring[j]), b.add(ring[j]), b.add(ring[i]), tint);
                }
            }
        }

        paint(x1, z1, x2, z2, width, tint, y = .017) {
            const dx = x2 - x1, dz = z2 - z1;
            const len = Math.hypot(dx, dz);
            if (!len) return;
            const ox = -dz * width / (len * 2), oz = dx * width / (len * 2);
            this.quad(V(x1 - ox, y, z1 - oz), V(x1 + ox, y, z1 + oz),
                V(x2 + ox, y, z2 + oz), V(x2 - ox, y, z2 - oz), tint);
        }

        ground(x1, z1, x2, z2, tint, y = 0) {
            this.quad(V(x1, y, z1), V(x1, y, z2), V(x2, y, z2), V(x2, y, z1), tint);
        }

        circle(x, z, radius, width, tint, sides = 60) {
            for (let i = 0; i < sides; i++) {
                const a = i * Math.PI * 2 / sides, b = (i + 1) * Math.PI * 2 / sides;
                this.paint(x + radius * Math.sin(a), z + radius * Math.cos(a),
                    x + radius * Math.sin(b), z + radius * Math.cos(b), width, tint);
            }
        }

        mesh(name, scene, parent, material) {
            const mesh = new BABYLON.Mesh(name, scene);
            const data = new BABYLON.VertexData();
            data.positions = this.positions;
            data.normals = this.normals;
            data.colors = this.colors;
            data.indices = this.indices;
            data.applyToMesh(mesh);
            mesh.material = material;
            mesh.parent = parent;
            mesh.isPickable = false;
            return mesh;
        }
    }

    const helmetLower = [
        [0, .203, -.393], [.102, .208, -.372], [.197, .224, -.327], [.267, .241, -.265],
        [.310, .211, -.189], [.338, .100, -.116], [.350, -.044, -.047], [.326, -.119, .077],
        [.285, -.166, .158], [.228, -.192, .218], [.155, -.209, .254], [.079, -.217, .276],
        [0, -.221, .286]
    ];
    const helmetBrow = [
        [0, .249, -.413], [.107, .254, -.392], [.205, .266, -.340], [.277, .284, -.270],
        [.322, .287, -.190], [.347, .244, -.111], [.363, .189, -.026], [.343, .157, .085],
        [.306, .132, .168], [.252, .118, .240], [.177, .112, .282], [.091, .112, .310],
        [0, .119, .324]
    ];
    const cage = [
        [[.341, .077, -.109], [.322, .067, -.231], [.239, .051, -.348], [.110, .041, -.422]],
        [[.333, -.023, -.116], [.306, -.039, -.234], [.225, -.065, -.342], [.103, -.072, -.408]],
        [[.315, -.109, -.144], [.284, -.129, -.232], [.199, -.161, -.311], [.091, -.175, -.376]]
    ];

    function kitHelmet(mesh, kit, skin) {
        mesh.loft([[-.267,.117,.127,-.055], [-.21,.208,.191,-.038], [-.079,.265,.240,-.024],
            [.116,.283,.251,-.015], [.261,.262,.246], [.338,.206,.171,.016], [.369,.094,.10,.021]], 10, skin);
        mesh.loft([[.03,.036,.028,-.25], [.14,.046,.039,-.251], [.182,.031,.020,-.243]], 6, skin);
        const crown = [
            [.314,.355,.294,.016,.013,.006], [.386,.297,.253,.024,.022,.014],
            [.437,.216,.186,.045,.022,.036], [.463,.119,.108,.069,.010,.017]
        ];
        const sides = 24;
        const rim = contour => Array.from({ length: sides }, (_, i) => {
            const row = contour[i > 12 ? 24 - i : i];
            return V(row[0] * (i > 12 ? -1 : 1), row[1], row[2]);
        });
        const rows = [rim(helmetLower), rim(helmetBrow), ...crown.map(row => Array.from({ length: sides }, (_, i) => {
            const angle = i * 2 * Math.PI / sides, cos = Math.cos(angle);
            const rear = Math.max(0, -cos) ** 5 * row[5];
            return V(row[1] * Math.sin(angle), row[0] - row[4] * cos + rear * .38, row[3] - row[2] * cos + rear);
        }))];
        const helmetHighlight = kit.helmet;
        for (let i = 0; i < sides; i++) {
            const side = Math.min(i + 1, sides - i), next = (i + 1) % sides;
            for (let j = 1; j < rows.length; j++) {
                const a = rows[j - 1][i], b = rows[j][i], c = rows[j][next], d = rows[j - 1][next];
                const brow = j === 1 && side < 5;
                mesh.quad(a, b, c, d, brow ? kit.trim : helmetHighlight);
                if (j === 3 && side >= 6 && side <= 8) {
                    const normal = BABYLON.Vector3.Cross(b.subtract(a), d.subtract(a)).normalize();
                    const point = (u, v) => BABYLON.Vector3.Lerp(BABYLON.Vector3.Lerp(a, d, u),
                        BABYLON.Vector3.Lerp(b, c, u), v).add(normal.scale(.004));
                    mesh.quad(point(.12,.50), point(.15,.72), point(.83,.69), point(.79,.44), dark);
                }
            }
            mesh.tri(rows.at(-1)[i], V(0, .483, .088), rows.at(-1)[next], helmetHighlight);
        }
        for (const row of cage) {
            const path = [...row.map(([x, y, z]) => V(-x, y, z)), ...[...row].reverse().map(p => V(...p))];
            mesh.rail(path, .021, "#b5c5d3", 5);
        }
        for (const side of [-1, 1]) {
            mesh.rail([V(side * .115, .263, -.380), V(side * .112, .13, -.414), V(side * .107, .04, -.421),
                V(side * .102, -.072, -.409), V(side * .088, -.224, -.349)], .018, "#c9d9e5", 5);
            mesh.rail([V(side * .346, -.013, -.064), V(side * .320, -.116, -.172),
                V(side * .266, -.207, -.294), V(side * .196, -.234, -.321)], .034, kit.trim, 5);
            mesh.box(side * .137, .107, -.249, .043, .020, .016, dark);
        }
        mesh.rail([V(-.196,-.234,-.321), V(-.105,-.246,-.348), V(.105,-.246,-.348), V(.196,-.234,-.321)], .025, kit.trim);
    }

    function stickShape(mesh, kit, pole) {
        const extension = pole ? .46 : 0, butt = pole ? -1.36 : -.923;
        const path = points => points.map(([x, y, z]) => V(x, y + extension, z));
        mesh.rail([V(0, butt, 0), V(0, .42 + extension, 0)], .023, "#cfd6db", 6);
        mesh.rail([V(0, -.53, 0), V(0, .145, 0)], .026, dark, 6);
        mesh.rail([V(0, butt, 0), V(0, butt + .11, 0)], .028, "#2d3647", 6);
        for (const sign of [-1, 1]) {
            mesh.rail(path([[sign * .039,.413,0], [sign * .105,.553,-.028], [sign * .172,.671,-.049],
                [sign * .221,.809,-.066], [sign * .214,.923,-.116], [sign * .169,.967,-.135]]),
            .022, kit.trim);
        }
        mesh.rail(path([[-.171,.966,-.135], [-.09,.994,-.149], [0,1.005,-.153],
            [.09,.994,-.149], [.171,.966,-.135]]), .027, white);
        const netRows = [[.48,.062,-.025], [.59,.123,0], [.70,.168,.029], [.81,.205,.001], [.921,.19,-.073], [.979,.123,-.136]];
        for (let row = 1; row < netRows.length; row++) {
            const [y1, w1, z1] = netRows[row - 1], [y2, w2, z2] = netRows[row];
            for (let k = -3; k <= 3; k++) {
                for (const step of [-1, 1]) {
                    if (Math.abs(k + step) > 3) continue;
                    mesh.rail(path([[k * w1 / 3, y1, z1], [(k + step) * w2 / 3, y2, z2]]), .006, "#d2e3e5", 3);
                }
            }
        }
    }

    const glyphs = [[0,1,2,3,4,5], [1,2], [0,1,6,4,3], [0,1,2,3,6], [5,6,1,2], [0,5,6,2,3],
        [0,5,4,6,2,3], [0,1,2], [0,1,2,3,4,5,6], [0,1,2,3,5,6]];
    const digitSegments = [
        [-.052,.121,.052,.121], [.068,.103,.068,.018], [.068,-.018,.068,-.102],
        [-.052,-.122,.052,-.122], [-.068,-.018,-.068,-.102], [-.068,.103,-.068,.018], [-.050,0,.050,0]
    ];

    function numberShape(mesh, number, tint) {
        const text = String(Math.abs(Number(number) || 0) % 100);
        const digits = [...text].filter(digit => glyphs[Number(digit)]);
        for (const front of [-1, 1]) {
            digits.forEach((digit, i) => {
                const offset = (i - (digits.length - 1) / 2) * .186;
                for (const segment of glyphs[Number(digit)]) {
                    const [x1, y1, x2, y2] = digitSegments[segment];
                    const flip = front > 0 ? -1 : 1;
                    mesh.rail([V((x1 + offset) * flip, .57 + y1, front * .238),
                        V((x2 + offset) * flip, .57 + y2, front * .238)], .016, tint, 4);
                }
            });
        }
    }

    class PlayerRig {
        constructor(view, player) {
            this.node = new BABYLON.TransformNode("athlete-" + player.id, view.scene);
            this.node.parent = view.root;
            this.body = new BABYLON.TransformNode("torso-joint", view.scene);
            this.body.parent = this.node;
            this.kit = view.kits[player.team] || view.kits[0];
            const skin = skins[Math.abs((player.slot || 0) + player.team * 2) % skins.length];
            const boneKey = player.team + ":" + skin;
            const part = (key, build, parent = this.node) => view.instance(boneKey + ":" + key, build, parent);
            this.torso = part("jersey", mesh => {
                const kit = this.kit;
                mesh.loft([[.18,.31,.188], [.31,.361,.221], [.65,.396,.226],
                    [.77,.403,.207], [.86,.254,.15]], 10, kit.jersey);
                mesh.loft([[.86,.136,.137], [1.08,.114,.12]], 8, skin);
                mesh.rail([V(-.167,.84,-.15), V(0,.765,-.21), V(.167,.84,-.15)], .021, kit.trim);
                mesh.loft([[.198,.317,.19], [.23,.333,.201]], 10, kit.trim);
            }, this.body);
            // Number art follows the torso and uses the kit's contrast color.
            this.number = view.instance("numbers:" + player.team + ":" + player.number,
                mesh => numberShape(mesh, player.number, this.kit.number), this.body);
            this.head = part("helmet", mesh => kitHelmet(mesh, this.kit, skin), this.body);
            this.head.position.y = 1.18;
            this.hips = part("waist", mesh => mesh.loft([[-.064,.307,.195], [.09,.346,.226],
                [.225,.330,.195]], 10, this.kit.shorts), this.body);

            this.long = player.role === "D" || player.role === "LSM" || player.longPole === true;
            this.stick = view.instance("stick:" + player.team + ":" + this.long,
                mesh => stickShape(mesh, this.kit, this.long), this.node);
            this.stick.rotationQuaternion = BABYLON.Quaternion.Identity();
            this.pocket = V();
            this.stickAxis = V(.63, .69, -.35).normalize();
            this.shadow = view.instance("ground shadow", mesh => {
                const rings = 24;
                for (let i = 0; i < rings; i++) {
                    const a = i * 2 * Math.PI / rings, b = (i + 1) * 2 * Math.PI / rings;
                    mesh.tri(V(0,.006), V(Math.sin(a)*.77,.006,Math.cos(a)*.61),
                        V(Math.sin(b)*.77,.006,Math.cos(b)*.61), "#16413d");
                }
            });

            this.limbs = [-1, 1].map(sign => {
                const upper = part("sleeve", mesh => {
                    mesh.loft([[-.51,.101,.109], [.08,.112,.128], [.48,.106,.113]], 8, skin);
                    mesh.loft([[.035,.134,.149], [.34,.149,.167], [.53,.121,.140]], 8, this.kit.jersey);
                    mesh.loft([[.045,.137,.151], [.108,.141,.154]], 8, this.kit.trim);
                });
                const lower = part("glove", mesh => {
                    mesh.loft([[.02,.084,.092], [.43,.114,.120], [.52,.101,.112]], 8, skin);
                    mesh.loft([[-.57,.089,.104], [-.46,.132,.138], [-.12,.135,.144], [.05,.095,.114]], 8, this.kit.trim);
                    mesh.loft([[-.44,.136,.141], [-.35,.14,.148]], 8, this.kit.helmet);
                });
                const upperLeg = part("shorts leg", mesh => {
                    mesh.loft([[-.52,.094,.110], [.0,.143,.142], [.50,.155,.160]], 8, skin);
                    mesh.loft([[-.22,.151,.157], [.04,.17,.166], [.52,.167,.178]], 8, this.kit.shorts);
                    mesh.loft([[-.237,.156,.162], [-.16,.16,.165]], 8, this.kit.trim);
                });
                const lowerLeg = part("lower leg", mesh => {
                    mesh.loft([[-.46,.091,.109], [.02,.105,.121], [.44,.108,.121], [.53,.095,.104]], 8, skin);
                    mesh.loft([[-.53,.101,.107], [-.32,.105,.117]], 8, white);
                });
                const boot = part("boot", mesh => {
                    mesh.loft([[-.12,.130,.221,-.079], [-.073,.144,.212,-.074], [.008,.138,.195,-.06],
                        [.098,.112,.112,.011]], 8, "#1a2440");
                    mesh.loft([[-.119,.139,.220,-.08], [-.086,.145,.225,-.08]], 8, white);
                    for (let i = 0; i < 3; i++) {
                        mesh.rail([V(-.052,.018+i*.019,-.16+i*.04), V(.052,.018+i*.019,-.16+i*.04)], .009, "#b7c6d2", 4);
                    }
                });
                return { sign, upper, lower, upperLeg, lowerLeg, boot };
            });
            this.gait = (player.slot || 0) * .8;
            this.bob = 0;
        }

        pose(player, dt) {
            this.node.position.set(player.x, 0, player.z);
            this.node.rotation.y = Number.isFinite(player.yaw) ? player.yaw : 0;
            this.shadow.position.set(player.x, 0, player.z);
            const speed = player.speed || 0;
            const effort = clamp(speed / 6.5, 0, 1);
            this.gait += dt * speed * 2.8;
            const p = clamp((player.actionTime || 0) / Math.max(.12, player.actionDuration || .45), 0, 1);
            const profile = Math.sin(p * Math.PI);
            const winding = (player.action === "shoot" || player.action === "pass") ? profile : 0;
            const checking = player.action === "check" ? profile : 0;
            const scooping = player.action === "scoop" ? profile : 0;
            const dodging = player.action === "dodge" ? profile : 0;
            const drawing = player.action === "faceoff" ? profile : 0;
            const crouch = .24 * Math.max(scooping, drawing, dodging * .6);
            const bob = effort * (1 - Math.cos(this.gait * 2)) * .025;
            this.body.position.set(0, 1.03 + bob - crouch, 0);
            this.body.rotation.set(-.16 * effort - .26 * scooping, winding * (.6 - 1.25 * p) + .12 * dodging,
                Math.sin(this.gait) * effort * .025 - .19 * dodging);
            this.head.rotation.y = -.18 * winding;
            const h = this.long ? .33 : 0;
            const stickVector = V(.63 - .22 * winding, .69 - .32 * checking - .43 * scooping,
                -.35 - .43 * winding - .54 * checking - .62 * scooping).normalize();
            const pocketDesired = V(.64 + h * .42 + .13 * dodging,
                2.26 + h + bob + .42 * winding - .93 * scooping - .59 * drawing,
                -.59 - h * .72 - .42 * winding * (2 * p - .85) - .38 * checking);
            this.stick.rotationQuaternion.copyFrom(orientation(stickVector));
            const pivot = V(0, .70 + (this.long ? .46 : 0), -.1);
            const offset = V();
            pivot.rotateByQuaternionToRef(this.stick.rotationQuaternion, offset);
            this.stick.position.copyFrom(pocketDesired.subtract(offset));

            for (const limb of this.limbs) {
                const { sign } = limb;
                const phase = this.gait + (sign < 0 ? Math.PI : 0);
                const stride = Math.cos(phase) * effort * .39;
                const lift = Math.max(0, Math.sin(phase)) * effort * .26;
                const foot = V(sign * (.20 + .10 * dodging), .12 + lift, stride - .04);
                const hip = V(sign * .203, 1.12 + bob - crouch * .75, .012);
                const knee = joint(hip, foot, .53, .50, V(0, 0, -1));
                aimBone(limb.upperLeg, hip, knee);
                aimBone(limb.lowerLeg, knee, foot);
                limb.boot.position.copyFrom(foot);
                limb.boot.rotation.x = lift * 1.06;

                const shoulder = V(sign * .46, 1.74 + bob - crouch, .01 + sign * winding * .14);
                const gripDistance = sign === 1 ? 0 : this.long ? -.48 : -.37;
                const wrist = this.stick.position.add(stickVector.scale(gripDistance));
                const elbow = joint(shoulder, wrist, .35, .34, V(sign * .62, -.91, .22));
                aimBone(limb.upper, shoulder, elbow);
                aimBone(limb.lower, elbow, wrist);
            }
            this.pocket.copyFrom(BABYLON.Vector3.TransformCoordinates(pocketDesired, this.node.computeWorldMatrix(true)));
        }
    }

    function joint(a, b, upper, lower, guide) {
        const delta = b.subtract(a), length = delta.length();
        const axis = length > 0 ? delta.scale(1 / length) : V(0, -1, 0);
        const t = clamp(length, .015, upper + lower - .003);
        const along = (upper * upper - lower * lower + t * t) / (2 * t);
        const normal = guide.subtract(axis.scale(BABYLON.Vector3.Dot(guide, axis))).normalize();
        return a.add(axis.scale(along)).add(normal.scale(Math.sqrt(Math.max(0, upper * upper - along * along))));
    }

    function orientation(axis) {
        const up = V(0, 1, 0);
        const dot = clamp(axis.y, -1, 1);
        if (dot > .9999) return BABYLON.Quaternion.Identity();
        if (dot < -.9999) return BABYLON.Quaternion.RotationAxis(V(1), Math.PI);
        const cross = BABYLON.Vector3.Cross(up, axis);
        return BABYLON.Quaternion.RotationAxis(cross.normalize(), Math.acos(dot));
    }

    function aimBone(mesh, top, bottom) {
        const direction = top.subtract(bottom);
        const length = direction.length();
        mesh.position.copyFrom(top.add(bottom).scale(.5));
        mesh.scaling.y = length;
        mesh.rotationQuaternion = orientation(length > 0 ? direction.scale(1 / length) : V(0, 1, 0));
    }

    function material(scene, name, tint, specular = "#222838", emissive) {
        const m = new BABYLON.StandardMaterial(name, scene);
        m.diffuseColor = C(tint);
        m.specularColor = C(specular);
        if (emissive) m.emissiveColor = C(emissive);
        // Vertex colors distinguish kit pieces without splitting a shared bone into submeshes.
        m.backFaceCulling = false;
        return m;
    }

    function fieldSetup(view) {
        const match = view.match;
        const wide = match.halfWidth || 27.43, length = match.halfLength || 50.29;
        const goalZ = match.goalZ || 36.58, h = match.goalTop || 1.83, g = match.goalHalfWidth || .9144;
        const goalLength = view.practice() ? [-(Math.abs(goalZ))] : [-Math.abs(goalZ), Math.abs(goalZ)];
        const turf = new Geometry();
        turf.ground(-wide - 45, -length - 45, wide + 45, length + 45, "#182f3b", -.08);
        for (let i = 0, start = -length; start < length - .001; i++, start += 5.029) {
            turf.ground(-wide, start, wide, Math.min(length, start + 5.029), i % 2 ? "#306b61" : "#37776a");
        }
        const lines = new Geometry(), structures = new Geometry(), crowd = new Geometry();
        const chalk = "#d5ede2";
        for (const side of [-1, 1]) {
            const x = side * wide, z = side * length;
            lines.paint(-wide, z, wide, z, .14, chalk);
            lines.paint(x, -length, x, length, .14, chalk);
            lines.paint(-wide, side * length * .363, wide, side * length * .363, .12, chalk);
            lines.paint(side * wide * .667, -length*.183, side * wide * .667, length*.183, .13, chalk);
            turf.ground(Math.min(x, x + side * 2.7), -length, Math.max(x, x + side * 2.7), length, "#233f4a", -.04);
            for (let at = -length + 2; at < length - 1; at += 2.2) {
                lines.paint(x + side * .90, at, x + side * .90, at + 1.1, .08, "#589c98", -.02);
            }
            for (let row = 0; row < 6; row++) {
                const standX = side * (wide + 4.4 + row * 1.3);
                const level = .63 + row * .45;
                structures.box(standX, level / 2, 0, 1.35, level, length * 2 + 4.0,
                    row % 2 ? "#25364c" : "#2e4257");
                structures.box(standX + side * .58, level + .018, 0, .055, .032, length * 2 + 4.1, "#576d7c");
                for (let p = -length; p < length; p += .8) {
                    const sample = Math.abs(Math.sin(p * 49.73 + row * 25.78 + side));
                    if (sample < .27 || Math.abs(p % 15) < .9) continue;
                    const index = Math.floor(sample * 5) % 5;
                    const tint = ["#525376", "#637687", "#655771", "#785d72", "#84979c"][index];
                    crowd.box(standX - side * .11, level + .238, p + sample * .2, .24, .48, .29, tint);
                    crowd.box(standX - side * .13, level + .52, p + sample * .2, .19, .185, .19, tint);
                }
            }
            structures.box(x + side * 3.3, .46, 0, .15, .92, length * 2 + 4, "#202b42");
            structures.box(x + side * 3.2, .88, 0, .11, .08, length * 2 + 4, "#62abaa");
            structures.box(0, .65, z + side * 2.8, wide * 2 + 5, 1.3, .32, "#1e2540");
            structures.box(0, 1.3, z + side * 2.8, wide * 2 + 5, .11, .44, "#5e6589");
        }
        lines.paint(-wide, 0, wide, 0, .24, "#e7ffef");
        lines.circle(0, 0, match.creaseRadius || 2.743, .085, "#79a59b", 48);
        lines.paint(-.35, 0, .35, 0, .24, "#f2b26b", .023);

        const goals = new Geometry();
        const netLines = [];
        for (const z of goalLength) {
            const sign = Math.sign(z);
            const back = z + sign * 1.24;
            lines.circle(0, z, match.creaseRadius || 2.743, .13, chalk);
            lines.paint(-g, z, g, z, .11, "#f5e6cf");
            goals.rail([V(-g, .03, z), V(-g, h, z), V(g, h, z), V(g, .03, z)], .064, "#ed763b", 8);
            goals.rail([V(-g, .022, z), V(-.69, .022, back), V(.69, .022, back), V(g, .022, z)], .032, silver);
            goals.rail([V(-g, h, z), V(-.69, .03, back)], .023, silver);
            goals.rail([V(g, h, z), V(.69, .03, back)], .023, silver);
            for (let i = 0; i <= 12; i++) {
                const u = i / 12;
                netLines.push([V(lerp(-g, g, u), h, z), V(lerp(-.69, .69, u), .06, back)]);
                if (i === 12) continue;
                for (const beam of [-1, 1]) {
                    netLines.push([V(beam * g, h * u, z), V(beam * .69, .045, back)]);
                }
            }
            for (let i = 1; i < 13; i++) {
                const u = i / 13, span = lerp(g, .69, u);
                netLines.push([V(-span, lerp(h, .06, u), lerp(z, back, u)), V(span, lerp(h, .06, u), lerp(z, back, u))]);
            }
        }
        turf.mesh("striped field", view.scene, view.root, view.flat).freezeWorldMatrix();
        lines.mesh("paint and creases", view.scene, view.root, view.flat).freezeWorldMatrix();
        structures.mesh("stadium terraces", view.scene, view.root, view.flat).freezeWorldMatrix();
        crowd.mesh("terrace spectators", view.scene, view.root, view.flat).freezeWorldMatrix();
        goals.mesh("lacrosse goals", view.scene, view.root, view.flat).freezeWorldMatrix();
        const net = BABYLON.MeshBuilder.CreateLineSystem("lacrosse goal mesh", { lines: netLines }, view.scene);
        net.parent = view.root;
        net.color = C("#d2e4e7");
        net.alpha = .52;
        net.isPickable = false;
        net.freezeWorldMatrix();
        return { wide, length };
    }

    function lightPoles(view, wide, length) {
        const body = new Geometry(), lamps = new Geometry();
        for (const x of [-wide - 5, wide + 5]) {
            for (const z of [-length * .8, length * .8]) {
                body.rail([V(x,.1,z), V(x,13.1,z)], .13, "#314458", 6);
                body.box(x, 13.1, z, .26, 1.08, 4.08, "#314458");
                for (const side of [-1, 1]) {
                    for (let column = 0; column < 6; column++) {
                        const pos = z + (column - 2.5) * .63;
                        lamps.box(x - Math.sign(x)*.15, 13.12+side*.245, pos, .035, .34, .50, "#d0f5ff");
                    }
                }
            }
        }
        body.mesh("light pylons", view.scene, view.root, view.flat).freezeWorldMatrix();
        const m = material(view.scene, "light tower lamps", "#fcfcff", "#000000", "#8793a3");
        lamps.mesh("floodlight heads", view.scene, view.root, m).freezeWorldMatrix();
    }

    return class LacrosseView {
        constructor(scene, match, options = {}) {
            this.scene = scene;
            this.match = match;
            this.root = new BABYLON.TransformNode("PolyLax arena", scene);
            this.kits = options.kits || palettes;
            this.templates = new Map();
            this.rigs = new Map();
            this.playing = null;
            this.cameraMode = 0;
            this.flat = material(scene, "PolyLax vertex materials", "#eceef1", "#161c25", "#293043");
            this.ambient = new BABYLON.HemisphericLight("arena fill", V(.2, 1, .2), scene);
            this.ambient.intensity = .92;
            this.ambient.groundColor = C("#73869a");
            this.ambient.diffuse = C("#e2eafa");
            this.key = new BABYLON.DirectionalLight("evening key", V(-.63, -1, .45), scene);
            this.key.intensity = .92;
            this.key.diffuse = C("#ffd6b3");
            this.ambient.parent = this.root;
            this.key.parent = this.root;
            scene.clearColor = BABYLON.Color4.FromHexString("#242947ff");
            scene.fogMode = BABYLON.Scene.FOGMODE_LINEAR;
            scene.fogColor = C("#454666");
            scene.fogStart = 38;
            scene.fogEnd = 132;

            this.camera = new BABYLON.FreeCamera("sidelined broadcast", V(0, 16, 18), scene);
            this.camera.inputs.clear();
            this.camera.minZ = .22;
            this.camera.maxZ = 185;
            this.camera.fov = .77;
            scene.activeCamera = this.camera;
            this.target = V();
            this.time = 0;
            const { wide, length } = fieldSetup(this);
            lightPoles(this, wide, length);
            this.marker = BABYLON.MeshBuilder.CreateTorus("controlled player ring",
                { diameter: 1.60, thickness: .066, tessellation: 30 }, scene);
            this.marker.parent = this.root;
            this.marker.material = material(scene, "control marker", "#23c9d6", "#000000", "#107481");
            this.marker.isPickable = false;
            this.ball = BABYLON.MeshBuilder.CreateIcoSphere("game ball", { radius: .145, subdivisions: 1 }, scene);
            this.ball.parent = this.root;
            this.ball.isPickable = false;
            this.ball.material = material(scene, "ball glow", "#fbf1aa", "#473632", "#c39c3c");
            this.aimLine = BABYLON.MeshBuilder.CreateLines("shot aim line", { points: [V(), V(.01)], updatable: true }, scene);
            this.aimLine.parent = this.root;
            this.aimLine.color = C("#fcea91");
            this.aimLine.isPickable = false;
            this.aimLine.setEnabled(false);
            this.retarget();
            this.render(0, false);
        }

        practice() {
            return this.match.mode === "practice" || this.match.halfWidth < 15;
        }

        instance(key, build, parent = this.root) {
            let template = this.templates.get(key);
            if (!template) {
                const geometry = new Geometry();
                build(geometry);
                template = geometry.mesh("base " + key, this.scene, this.root, this.flat);
                template.isVisible = false;
                this.templates.set(key, template);
            }
            const instance = template.createInstance("rig " + key);
            instance.parent = parent;
            instance.isVisible = true;
            instance.isPickable = false;
            return instance;
        }

        retarget() {
            for (const player of this.match.players) {
                if (!this.rigs.has(player.id)) this.rigs.set(player.id, new PlayerRig(this, player));
            }
        }

        setAim(aim) {
            this.aim = aim && Number.isFinite(aim.x) && Number.isFinite(aim.y) && Number.isFinite(aim.z) ? aim : null;
            this.aimLine.setEnabled(!!this.aim);
        }

        cycleCamera() {
            this.cameraMode = (this.cameraMode + 1) % 2;
            return this.cameraMode;
        }

        render(dt, playing = true) {
            const match = this.match;
            const controlled = match.players.find(p => p.id === match.controlled) || match.players[0];
            if (!controlled) return;
            this.time += dt;
            this.retarget();
            for (const player of match.players) this.rigs.get(player.id).pose(player, dt);
            const ball = match.ball;
            const owner = this.rigs.get(ball.owner);
            this.ball.position.copyFrom(owner ? owner.pocket : V(ball.x, Math.max(.105, ball.y), ball.z));
            if (this.aim) {
                const p = this.rigs.get(controlled.id).pocket;
                BABYLON.MeshBuilder.CreateLines("shot aim line",
                    { points: [p, V(this.aim.x, this.aim.y, this.aim.z)], instance: this.aimLine });
            }
            this.marker.position.set(controlled.x, .061, controlled.z);
            this.marker.setEnabled(playing);

            const wide = match.halfWidth, length = match.halfLength;
            const goal = -Math.abs(match.goalZ);
            const baseX = clamp(controlled.x + clamp((ball.x - controlled.x) * .16, -3, 3), -wide + 2, wide - 2);
            let pos, target;
            if (!playing) {
                const drift = Math.sin(this.time * .45) * 1.1;
                const z = this.practice() ? 7 : Math.min(19, length * .36);
                pos = V(-6.7 + drift, 7.7, z);
                target = V(2.2, 1.2, z - 17);
            } else {
                const wideView = this.cameraMode === 1;
                const focusZ = controlled.z - (wideView ? 4.8 : 3.2);
                const followBall = clamp((ball.z - focusZ) * .15, -3.5, 2.0);
                const goalClose = Math.abs(goal - controlled.z) < 14;
                const depth = (wideView ? 18 : 11.0) + (goalClose ? -.7 : 0);
                pos = V(baseX + clamp(controlled.x * -.07, -2.0, 2.0), wideView ? 23 : 9.9, controlled.z + depth);
                target = V(baseX, wideView ? .9 : 1.12, clamp(focusZ + followBall, -length + 1, length - 1));
                if (this.aim) target.z = lerp(target.z, this.aim.z + 4, .30);
            }
            const snap = this.playing === null || (this.playing !== playing && dt === 0);
            const blend = snap ? 1 : 1 - Math.exp(-Math.max(0, dt) * (playing ? 7.5 : 3.1));
            BABYLON.Vector3.LerpToRef(this.camera.position, pos, blend, this.camera.position);
            BABYLON.Vector3.LerpToRef(this.target, target, blend, this.target);
            this.camera.setTarget(this.target);
            this.playing = playing;
        }

        dispose() {
            this.camera.dispose();
            this.root.dispose(false, true);
        }
    };
})();
