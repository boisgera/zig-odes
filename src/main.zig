const std = @import("std");

const stdout = std.io.getStdOut().writer();
const pi = std.math.pi;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const T = f64;
const DT = f64;
const X = [2]f64;
const DX = [2]f64;
const Fun = fn (T, X) DX;
const TX = struct {
    t: T,
    x: X,
};

const Path = struct {
    const Self = @This();

    txs: std.ArrayList(TX),

    fn get_loc(self: Self, t: T) struct { i: usize, frac: f64 } {
        var i: usize = 0;
        while (i < self.txs.items.len) : (i += 1) {
            if (self.txs.items[i].t > t) {
                break;
            }
        }
        if (i == 0) {
            return .{ .i = 0, .frac = 0.0 };
        } else if (i == self.txs.items.len) {
            return .{ .i = self.txs.items.len - 1, .frac = 1.0 };
        } else {
            const dt = self.txs.items[i].t - self.txs.items[i - 1].t;
            const frac = (t - self.txs.items[i - 1].t) / dt;
            return .{ .i = i - 1, .frac = frac };
        }
    }

    fn get(self: Self, t: T) X {
        const loc = self.get_loc(t);
        const i = loc.i;
        var i_next = i + 1;
        if (i == self.txs.items.len - 1) {
            i_next = i;
        }
        const x0 = self.txs.items[i].x;
        const x1 = self.txs.items[i_next].x;
        var x: X = x0;
        for (0..x.len) |j| {
            x[j] += loc.frac * (x1[j] - x0[j]);
        }
        return x;
    }

    fn getMany(self: Self, ts: []const T) []X {
        var xs = allocator.alloc(X, ts.len) catch unreachable;
        for (0..ts.len) |i| {
            xs[i] = self.get(ts[i]);
        }
        return xs;
    }
};

fn rot(t: T, x: X) DX {
    _ = t;
    const dx0 = -x[1];
    const dx1 = x[0];
    return .{ dx0, dx1 };
}

fn eulerStep(comptime fun: Fun, t: T, x: X, dt: DT) DX {
    var x_next = x;
    const ftx = fun(t, x);
    for (0..x.len) |i| {
        x_next[i] += dt * ftx[i];
    }
    return x_next;
}

fn eulerPath(comptime fun: Fun, t0: T, x0: X, t1: T, dt: DT) Path {
    var txs = std.ArrayList(TX).init(allocator);
    var t = t0;
    var x = x0;
    txs.append(.{ .t = t, .x = x }) catch unreachable;
    while (t < t1) {
        x = eulerStep(fun, t, x, dt);
        t += dt;
        txs.append(.{ .t = t, .x = x }) catch unreachable;
    }
    return Path{ .txs = txs };
}

pub fn main() !void {
    try stdout.print("Hello, world!\n", .{});
    const path = eulerPath(rot, 0.0, .{ 1.0, 0.0 }, pi, 0.1);
    for (path.txs.items) |tx| {
        try stdout.print("{}, {any}\n", .{ tx.t, tx.x });
    }
    try stdout.print("---------------------------------\n", .{});
    const ts = [_]T{ 0.0, pi / 2.0, pi, pi, 3.0 * pi / 2.0, 2.0 * pi };
    const xs = path.getMany(&ts);
    for (0..ts.len) |i| {
        try stdout.print("{}, {any}\n", .{ ts[i], xs[i] });
    }
}
