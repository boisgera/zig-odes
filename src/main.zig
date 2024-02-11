const std = @import("std");
const odes = @import("odes.zig");

const pi = std.math.pi;

fn rot(t: f64, x: [2]f64) [2]f64 {
    _ = t;
    const dx0 = -x[1];
    const dx1 = x[0];
    return .{ dx0, dx1 };
}

pub fn main() !void {
    const ode = odes.ode(rot);

    const path = ode.Flow(0.0, .{ 1.0, 0.0 }, pi, 0.1);
    for (path.txs.items) |tx| {
        std.debug.print("{}, {any}\n", .{ tx.t, tx.x });
    }
    std.debug.print("---------------------------------\n", .{});
    const ts = [_]f64{ 0.0, pi / 2.0, pi, pi, 3.0 * pi / 2.0, 2.0 * pi };
    const xs = path.getMany(&ts);
    for (0..ts.len) |i| {
        std.debug.print("{}, {any}\n", .{ ts[i], xs[i] });
    }
}
