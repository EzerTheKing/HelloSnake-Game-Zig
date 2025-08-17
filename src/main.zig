const rl = @import("raylib");
const std = @import("std");
const print = std.debug.print;

const Point = struct {
    x: i16 = 1,
    y: i16 = 0,
};

const RndGen = std.rand.DefaultPrng;

const Game = struct {
    direction: Point = Point{},
    allocator: std.mem.Allocator,
    W: i16,
    H: i16,
    snake: std.ArrayList(Point),
    food: Point = Point{},
    pub fn init(allocator: std.mem.Allocator, W: i16, H: i16) !*Game {
        const game = try allocator.create(Game);
        game.* = Game{
            .W = W,
            .H = H,
            .snake = std.ArrayList(Point).init(allocator),
            .allocator = allocator,
        };
        try game.snake.append(Point{ .x = 20, .y = 15 });
        game.freshFood();
        return game;
    }

    pub fn move(game: *Game) !void {
        var i = game.snake.items.len - 1;
        const tailx = game.snake.items[i].x;
        const taily = game.snake.items[i].y;

        while (i > 0) : (i -= 1) {
            game.snake.items[i].x = game.snake.items[i - 1].x;
            game.snake.items[i].y = game.snake.items[i - 1].y;
        }
        game.snake.items[0].x += game.direction.x;
        game.snake.items[0].y += game.direction.y;

        if (game.food.x == game.snake.items[0].x
        and game.snake.items[0].y == game.food.y) {
            try game.snake.append(Point{ .x = tailx, .y = taily });
            game.freshFood();
        }
    }

    pub fn freshFood(game: *Game) void {
        const seed: u64 = @intCast(std.time.nanoTimestamp());
        var prng = std.Random.DefaultPrng.init(seed);
        var rng = prng.random();
        game.food.x = rng.intRangeAtMost(i16, 2, game.W - 1);
        game.food.y = rng.intRangeAtMost(i16, 0, game.H - 1);
    }

    pub fn crashed(game: *Game) bool {
        var i = game.snake.items.len - 1;
        while (i > 0) : (i -= 1) {
            const it = game.snake.items[i];
            if (it.x == game.snake.items[0].x
            and it.y == game.snake.items[0].y) {
                return true;
            }
        }

        if (game.snake.items[0].x < 0
        or game.snake.items[0].y < 0
        or game.snake.items[0].x >= game.W
        or game.snake.items[0].y >= game.H) {
            return true;
        }
        return false;
    }

    pub fn deinit(game: *Game) void {
        game.snake.deinit();
    }
};

fn drawInnerFrame(thickness: i32, color: rl.Color, screenWidth: i32, screenHeight: i32) void {
    rl.drawRectangleLinesEx(
        rl.Rectangle{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(screenWidth),
            .height = @floatFromInt(screenHeight),
        },
        @floatFromInt(thickness),
        color,
    );
}

fn drawAppleIcon(x: i32, y: i32) void {
    rl.drawCircle(x, y, 12, rl.Color.red);
    rl.drawCircle(x - 4, y - 4, 3,
        rl.Color{ .r = 255, .g = 200, .b = 200, .a = 160 });
    rl.drawTriangle(
        rl.Vector2{ .x = @floatFromInt(x + 8), .y = @floatFromInt(y - 10) },
        rl.Vector2{ .x = @floatFromInt(x + 2), .y = @floatFromInt(y - 4) },
        rl.Vector2{ .x = @floatFromInt(x + 12), .y = @floatFromInt(y) },
        rl.Color.green,
    );
    rl.drawLine(x, y - 12, x, y - 18,
        rl.Color{ .r = 90, .g = 50, .b = 20, .a = 255 });
}

fn drawTrophyIcon(x: i32, y: i32) void {
    const gold = rl.Color{ .r = 255, .g = 215, .b = 0, .a = 255 };
    rl.drawRectangle(x - 10, y - 8, 20, 12, gold);
    rl.drawRectangle(x - 6, y + 4, 12, 4, gold);
    rl.drawCircleLines(x - 14, y - 2, 6, gold);
    rl.drawCircleLines(x + 14, y - 2, 6, gold);
    rl.drawRectangle(x - 3, y + 8, 6, 10, gold);
    rl.drawRectangle(x - 10, y + 18, 20, 4, gold);
}

fn drawHUD(screenWidth: i32, score: usize, best: usize) !void {
    const barH: i32 = 48;
    rl.drawRectangle(0, 0, screenWidth, barH,
        rl.Color{ .r = 46, .g = 125, .b = 50, .a = 200 });
    rl.drawRectangle(0, barH - 2, screenWidth, 2,
        rl.Color{ .r = 0, .g = 0, .b = 0, .a = 60 });

    drawAppleIcon(28, 24);
    var buf1: [32]u8 = undefined;
    const txt1 = try std.fmt.bufPrintZ(&buf1, "{d}", .{score});
    rl.drawText(txt1, 48, 12, 24, rl.Color.white);

    drawTrophyIcon(120, 20);
    var buf2: [32]u8 = undefined;
    const txt2 = try std.fmt.bufPrintZ(&buf2, "{d}", .{best});
    rl.drawText(txt2, 140, 12, 24, rl.Color.white);
}

fn drawCheckerBackground(cellsize: i16, W: i16, H: i16) void {
    const c1 = rl.Color{ .r = 100, .g = 140, .b = 70, .a = 255 };
    const c2 = rl.Color{ .r = 90, .g = 130, .b = 60, .a = 255 };
    var y: i16 = 0;
    while (y < H) : (y += 1) {
        var x: i16 = 0;
        while (x < W) : (x += 1) {
            const color = if (((@as(i32, x) + @as(i32, y)) & 1) == 0)
                c1
            else
                c2;
            rl.drawRectangle(
                @intCast(x * cellsize),
                @intCast(y * cellsize),
                @intCast(cellsize),
                @intCast(cellsize),
                color,
            );
        }
    }
}

pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 550;
    const cellsize: i8 = 20;
    const frametime: u64 = 100_000_000;

    var game = try Game.init(std.heap.page_allocator, 40, 30);
    defer game.deinit();

    rl.initWindow(screenWidth, screenHeight, "Hello Snake");
    defer rl.closeWindow();

    var previoustime = std.time.nanoTimestamp();
    rl.setTargetFPS(30);

    var best_score: usize = 0;

    while (!rl.windowShouldClose()) {
        if (rl.isKeyDown(.q)) break;

        if (rl.isKeyDown(.a)) {
            game.direction.x = -1;
            game.direction.y = 0;
        }
        if (rl.isKeyDown(.s)) {
            game.direction.x = 0;
            game.direction.y = 1;
        }
        if (rl.isKeyDown(.w)) {
            game.direction.x = 0;
            game.direction.y = -1;
        }
        if (rl.isKeyDown(.d)) {
            game.direction.x = 1;
            game.direction.y = 0;
        }

        const now = std.time.nanoTimestamp();
        if (now - previoustime >= frametime) {
            previoustime = now;
            try game.move();
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        drawCheckerBackground(cellsize, game.W, game.H);

        rl.drawCircle( @intCast(game.food.x * cellsize + cellsize / 2), @intCast(game.food.y * cellsize + cellsize / 2), @floatFromInt(cellsize / 2), rl.Color.red);

        for (game.snake.items) |it| { rl.drawRectangle(@intCast(it.x * cellsize), @intCast(it.y * cellsize), @intCast(cellsize), @intCast(cellsize), rl.Color.white); }

        const score: usize = if (game.snake.items.len == 0) 0 else game.snake.items.len - 1;
        if (score > best_score) best_score = score; try drawHUD(screenWidth, score, best_score);
        drawInnerFrame(6, rl.Color{ .r = 20, .g = 70, .b = 30, .a = 255 }, screenWidth, screenHeight + 36); rl.drawText("Q - EXIT", 680, 15, 20, rl.Color.white);
        if (game.crashed()) break;
        }
}
