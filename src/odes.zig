const std = @import("std");

const stdout = std.io.getStdOut().writer();

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub fn ode(comptime fct: anytype) type {
    const fct_type = @TypeOf(fct);
    const type_info = @typeInfo(fct_type);
    const params = type_info.Fn.params;

    return struct {
        pub const fun = fct;

        const Self = @This();

        pub const F: type = blk: {
            if (params[0].type) |t| {
                break :blk t;
            } else {
                @compileError("invalid time type");
            }
        };

        pub const n: comptime_int = blk: {
            if (params[1].type) |t| {
                break :blk @typeInfo(t).Array.len;
            } else {
                @compileError("invalid state space vector");
            }
        };

        pub const T = F;
        pub const DT = F;
        pub const X = [n]F;
        pub const DX = [n]F;
        pub const TX = struct {
            t: T,
            x: X,
        };
        pub const Fun = fn (T, X) DX;

        pub const Path = struct {
            txs: std.ArrayList(TX), // Or two arrayslists ?

            pub fn get_loc(path: Path, t: T) struct { i: usize, frac: f64 } {
                var i: usize = 0;
                while (i < path.txs.items.len) : (i += 1) {
                    if (path.txs.items[i].t > t) {
                        break;
                    }
                }
                if (i == 0) {
                    return .{ .i = 0, .frac = 0.0 };
                } else if (i == path.txs.items.len) {
                    return .{ .i = path.txs.items.len - 1, .frac = 1.0 };
                } else {
                    const dt = path.txs.items[i].t - path.txs.items[i - 1].t;
                    const frac = (t - path.txs.items[i - 1].t) / dt;
                    return .{ .i = i - 1, .frac = frac };
                }
            }

            pub fn get(path: Path, t: T) X {
                const loc = path.get_loc(t);
                const i = loc.i;
                var i_next = i + 1;
                if (i == path.txs.items.len - 1) {
                    i_next = i;
                }
                const x0 = path.txs.items[i].x;
                const x1 = path.txs.items[i_next].x;
                var x: X = x0;
                for (0..x.len) |j| {
                    x[j] += loc.frac * (x1[j] - x0[j]);
                }
                return x;
            }

            pub fn getMany(path: Path, ts: []const T) []X {
                var xs = allocator.alloc(X, ts.len) catch unreachable;
                for (0..ts.len) |i| {
                    xs[i] = path.get(ts[i]);
                }
                return xs;
            }
        };

        fn Step(t: T, x: X, dt: DT) DX {
            var x_next = x;
            const ftx = fun(t, x);
            for (0..x.len) |i| {
                x_next[i] += dt * ftx[i];
            }
            return x_next;
        }

        pub fn Flow(t0: T, x0: X, t1: T, dt: DT) Path {
            var txs = std.ArrayList(TX).init(allocator);
            var t = t0;
            var x = x0;
            txs.append(.{ .t = t, .x = x }) catch unreachable;
            while (t < t1) {
                x = Step(t, x, dt);
                t += dt;
                txs.append(.{ .t = t, .x = x }) catch unreachable;
            }
            return Path{ .txs = txs };
        }
    };
}
