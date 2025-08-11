package game

import "base:runtime"
import "core:log"
import "core:time"
import "core:math"
import "core:math/rand"
import "core:fmt"
import "core:math/linalg"

import "../atlas"

vec2 :: [2]f32
vec3 :: [3]f32
vec4 :: [4]f32
MAX_SPRITES :: 8192

Sprite :: struct #align(16) {
    pos : vec2,
    size : vec2,
    atlaspos : vec2,
    atlas_size : vec2,
    color : vec3,
}

Constants :: struct #align(16) {
    screensize : vec2,
    atlassize  : vec2,
}

SpriteBatch :: struct {
    sprite : []Sprite,
    size : u32,
}

ButtonState :: struct {
    half_transition_count: int,
    ended_down: bool,
}

Buttons :: enum {
    Move_Up,
    Move_Down,
    Start,
    Back,
}

GameState :: struct {
    paddle : vec4,
    ai_paddle : vec4,
    ball : vec4,
    ball_dir : vec2,
    ball_speed : f32,
    paddle_speed : f32,
    score: u32,
    dt: f32,
    new_input : [Buttons]ButtonState,
    score_cpu : u32,
    ai_target_y: f32,
    ai_reaction_delay: f32,
    ai_reaction_timer: f32,
    ai_ctimer, p_ctimer : time.Tick,
    screen : vec2,
    play_sound : proc(),
    p : Particle,
    sound_playing : b32,
}

Particle :: struct {
    pos : []vec2,
    dir : []vec2,
    timer : f32,
    count : u32,
}

HV_WHITE :: vec3{1, 1, 1}
HV_RED   :: vec3{1.0, 0.1, 0.1}
HV_GREEN :: vec3{0.2, 0.8, 0.4}
HV_BLUE  :: vec3{0, 0, 1}
HV_BLACK :: vec3{0, 0, 0}



sb : SpriteBatch


hv_append ::#force_inline proc(sb1 : ^SpriteBatch, sprpos : vec4, atlpos : atlas.Rect, color : vec3) {
    sb1.sprite[sb1.size].pos =  {sprpos.x, sprpos.y}
    sb1.sprite[sb1.size].size = {sprpos.z, sprpos.w}
    sb1.sprite[sb1.size].atlaspos = {atlpos.x, atlpos.y}
    sb1.sprite[sb1.size].atlas_size = {atlpos.z, atlpos.w}
    sb1.sprite[sb1.size].color = color
    sb1.size += 1
}

draw_text :: proc (pos: vec2, text : string, color : vec3 = HV_WHITE) {
    startx := pos.x
    starty := pos.y

    for slovo in text {
        fnt := atlas.glyphs[0]
        if slovo == ' ' {
            startx += 17
            continue
        }
        for glyph in atlas.glyphs {
            if glyph.value == slovo {
                fnt = glyph
                break
            }
        }

        if(slovo == '\n') {
            starty += fnt.rect.y
            startx =  pos.x
            continue
        }

        startx1 := startx + f32(fnt.offset_x)
        starty1 := starty + f32(fnt.offset_y)

        endx := fnt.rect.z
        endy := fnt.rect.w

        hv_append(&sb, vec4{startx1, starty1, endx, endy}, fnt.rect, color)

        //__draw(vb, {startx1, starty1, endx, endy}, tex, color)

        startx += f32(fnt.advance_x)

    }
}

calc_text_len :: proc(text : string) -> u32 {
    startx : u32 = 0

    for c in text {
        fnt := atlas.glyphs[0]

        if c == ' ' {
            startx += 17
            continue
        }

        for glyph in atlas.glyphs {
            if glyph.value == c {
                fnt = glyph
                break
            }
        }

        startx += u32(fnt.advance_x)
    }
    return startx
}

draw_sprite ::#force_inline proc(tname : atlas.TextureName, pos : vec4, color : vec3 = HV_WHITE) {
    hv_append(&sb, pos, atlas.textures[tname].rect, color)
}

draw_sprite_v2 ::#force_inline proc(tname : atlas.TextureName, pos : vec2, color : vec3 = HV_WHITE)  {
    w := atlas.textures[tname].rect.z
    h := atlas.textures[tname].rect.w
    hv_append(&sb, {pos.x, pos.y, w, h}, atlas.textures[tname].rect, color)
}

draw_rectangle ::#force_inline proc(pos : vec4, color : vec3 = HV_WHITE) {
    hv_append(&sb, pos, atlas.glyphs[len(atlas.glyphs) - 8].rect, color)
}

process_keyboard_message :: proc(new_state: ^ButtonState, is_down: bool) {
    if new_state.ended_down != is_down {
        new_state.ended_down = is_down
        new_state.half_transition_count += 1
    }
}

was_pressed :: proc(state : ^ButtonState) -> bool {
	result  : bool = ((state.half_transition_count > 1) ||
	                 ((state.half_transition_count == 1) &&
	                  (state.ended_down)))
	return result
}

init_p :: proc(p : ^Particle, pos : vec2, range : vec2) {

    for i : i32 = 0; i < i32(len(p.pos)); i += 1 {
        p.pos[i].x = pos.x
        p.pos[i].y = pos.y

        angle := rand.float32_range(range.x, range.y)

        r := math.to_radians(angle)

        p.dir[i].x = math.cos(r)
        p.dir[i].y = math.sin(r)
    }
    p.count = 10
    p.timer = 0
}

reset :: proc(gs : ^GameState) {
    angle := rand.float32_range(-46, 45)
    r := math.to_radians(angle)

    gs.ball_dir.x = math.cos(r)
    gs.ball_dir.y = math.sin(r)

    if rand.float32() < 0.5 {
        gs.ball_dir.x *= -1
    }

    gs.ball.x = gs.screen.x / 2 - gs.ball.z / 2
    gs.ball.y = gs.screen.y / 2 - gs.ball.w / 2

    //gs.paddle.z = 30;  gs.ai_paddle.z  = 30
    //gs.paddle.w = 180; gs.ai_paddle.w = 180

    //gs.ai_paddle.x = winsize.x - 40

    //gs.ball.z = 30
    //gs.ball.w = 30

    //gs.paddle_speed = 420
    //gs.ball_dir = vec2{1, 1}
    //gs.ball_speed = 610

    //gs.paddle.x = 10
    //gs.paddle.y = winsize.y / 2 - gs.paddle.w / 2
    //gs.ai_paddle.y = gs.paddle.y
}

init_game :: proc(using gs : ^GameState) {
    paddle.z = 30
    ai_paddle.z  = 30
    paddle.w = 180
    ai_paddle.w = 180

    ai_paddle.x = screen.x - 40

    ball.z = 30
    ball.w = 30

    paddle_speed = screen.x * 0.5
    ball_dir = vec2{1, 1}
    ball_speed = screen.x * 0.7

    paddle.x = 10
    paddle.y = screen.y / 2 - paddle.w / 2
    ai_paddle.y = paddle.y
    ai_reaction_delay = 0.1
    reset(gs)
}

check_collision :: proc(rec1, rec2 : vec4) -> b32 {
    return ((rec1.x < (rec2.x + rec2.z) && (rec1.x + rec1.z) > rec2.x) &&
            (rec1.y < (rec2.y + rec2.w) && (rec1.y + rec1.w) > rec2.y));
}


ball_dir_calculate :: proc(ball: vec4, paddle: vec4) -> (vec2, bool) {
    if check_collision(ball, paddle) {
        ball_center := vec2{ball.x + ball.z / 2, ball.y + ball.w / 2}
        paddle_center := vec2{paddle.x + paddle.z / 2, paddle.y + paddle.w / 2}
        return linalg.normalize0(ball_center - paddle_center), true
    }
    return {}, false
}


update :: proc (using game: ^GameState) {
    //t1 := time.duration_seconds(time.tick_since(start_tick))

    //screen := vec2{render.viewport.Width, render.viewport.Height}

    if new_input[.Move_Up].ended_down  {
        paddle.y -= paddle_speed * dt
    }
    if new_input[.Move_Down].ended_down {
        paddle.y += paddle_speed * dt
    }

    paddle.y = linalg.clamp(paddle.y, 0, screen.y - paddle.w)

    ai_reaction_timer += dt
    // if the timer is done:
    if ai_reaction_timer >= ai_reaction_delay {
        // reset the timer
        ai_reaction_timer = 0
        // use ball from last frame for extra delay
        ball_mid := ball.y + ball.w / 2
        // if the ball is heading left
        if ball_dir.x > 0 {
            // set the target to the ball
            ai_target_y = ball_mid - ai_paddle.w / 2
            // add or subtract 0-20 to add inaccuracy
            ai_target_y += rand.float32_range(-20, 20)
        } else {
            // set the target to screen middle
            ai_target_y = screen.y / 2 - ai_paddle.w / 2
        }
    }

    p.timer += dt
    if p.timer < 0.4 {
        for i : i32 = 0; i < i32(len(p.pos)); i += 1 {
            p.pos[i] += p.dir[i] * 120  * dt
        }
    } else {
        p.count = 0
    }

    // calculate the distance between paddle and target
    ai_paddle_mid := ai_paddle.y + ai_paddle.w / 2
    target_diff := ai_target_y - ai_paddle.y
    // move either paddle_speed distance or less
    // won't bounce around so much
    ai_paddle.y += linalg.clamp(target_diff, (-paddle_speed * 0.65 * dt),
        (paddle_speed * 0.65  * dt))
    // clamp to window_size
    ai_paddle.y = linalg.clamp(ai_paddle.y, 0, screen.y - ai_paddle.w)

    //paddle.y = linalg.clamp(paddle.y, 0, screen.y - paddle.w)

    //diff := ai_paddle.y + ai_paddle.w / 2 - ball.y + ball.w / 2
    //if diff < 0 {
    //    ai_paddle.y += (paddle_speed * 0.5) * dt
    //} else if diff > 0 {
    //    ai_paddle.y -= (paddle_speed * 0.5) * dt
    //}

    //ai_paddle.y = linalg.clamp(ai_paddle.y, 0, screen.y - ai_paddle.w)

    next_ball_pos := ball
    next_ball_pos.x += f32(ball_speed) * ball_dir.x * dt
    next_ball_pos.y += f32(ball_speed) * ball_dir.y * dt

    if next_ball_pos.y > screen.y - ball.w  || next_ball_pos.y < 1 {
        ball_dir.y *= -1
    }

    cpu_change := false

    if next_ball_pos.x > screen.x - ball.z  || next_ball_pos.x < 1 {
        reset(game)
        if next_ball_pos.x > 1 {
            score += 1

        } else  {
            cpu_change = true
            score_cpu += 1
        }
    }


    //player_hit := false
    new_dir, player_hit := ball_dir_calculate(ball, paddle)
    if player_hit {
        ball_dir = new_dir
        p_ctimer = time.tick_now()
        p_y := ball.y + (ball.w / 2)
        init_p(&p, {paddle.x + paddle.z, p_y}, {-90, 90})
        if !sound_playing {
            sound_playing = true
            if play_sound != nil { play_sound() }
        }
    }

    new_dir, player_hit = ball_dir_calculate(ball, ai_paddle)
    if player_hit {
        ball_dir = new_dir
        ai_ctimer = time.tick_now()
        p_y := ball.y + (ball.w / 2)
        init_p(&p, {ai_paddle.x, p_y}, {90, 270})
        //play_sound(gsound, source_voice)
        if !sound_playing {

            if play_sound != nil { play_sound() }
            sound_playing = true
        }
    }


    ball.x += ball_speed * ball_dir.x * dt
    ball.y += ball_speed * ball_dir.y * dt

    ball.y = linalg.clamp(ball.y, 0, screen.y - ball.w)
    ball.x = linalg.clamp(ball.x, 0, screen.x - ball.z)

    for y_line : f32 = 0; y_line < screen.y; y_line += 90 {
        draw_rectangle({screen.x / 2 - 5, y_line, 10, 80})
        //draw_rectangle({screen.x / 2 - 5, 150, 10, 80})
    }
    //this uses temp_allocator??
    score_str := fmt.tprintf("Player : %d", score)
    score_cpu_str := fmt.tprintf("CPU : %d", score_cpu)
    //defer delete(score_str)
    score_len := calc_text_len(score_str)
    score_cpu_len := calc_text_len(score_cpu_str)
    draw_rectangle({screen.x / 2 - f32(score_len) - 25, 0, 5, 50})
    draw_rectangle({screen.x / 2 - f32(score_len) - 25, 50,
        f32(score_len + score_cpu_len) + 50, 5})
    draw_rectangle({screen.x / 2 + f32(score_cpu_len) + 20, 0, 5, 50})
    draw_text(vec2{screen.x / 2 - f32(score_len) - 10, 10},
        score_str, HV_GREEN)
    draw_text(vec2{screen.x / 2 + 15, 10}, score_cpu_str, HV_RED)
    //draw_sprite(.Body_Template0, vec4{50, 50, 200, 200},)
    if f32(time.duration_seconds(time.tick_since(p_ctimer))) < 0.2 {
        draw_rectangle(paddle, HV_GREEN)
    } else {
        draw_rectangle(paddle)
    }
    if f32(time.duration_seconds(time.tick_since(ai_ctimer))) < 0.2 {
        draw_rectangle(ai_paddle, HV_RED)
    } else {
        draw_rectangle(ai_paddle)
    }
    draw_rectangle(ball, HV_RED)
    for i : u32 = 0; i < p.count; i += 1 {
        pa := p.pos[i]
        draw_rectangle({pa.x, pa.y, 4, 4})
    }
}
