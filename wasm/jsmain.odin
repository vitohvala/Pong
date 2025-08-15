package Pong

import "core:sys/wasm/js"
import gl "vendor:wasm/WebGL"
import "core:log"

import "base:runtime"
import stbi "vendor:stb/image"

import "core:fmt"

import g "../game"
import atlas "../atlas"

@(default_calling_convention="contextless") foreign { play_sound :: proc() --- }

//play_sound :: proc() {
//    js.set_element_key_string("sfx", "autoplay", "true")
//}

MAX_QUADS :: g.MAX_SPRITES * 6

TEXTURE_ATLAS :: #load("../assets/atlas.png")

WIDTH :: 1280
HEIGHT :: 720

Vertex :: struct {
    pos : [3]f32,
    tex : [2]f32,
    color : [3]f32,
}

Batch :: struct {
    vert : []Vertex,
    count : int,
}

Context :: struct {
    sb : Batch,
    accum_time : f64,
    vao : gl.VertexArrayObject,
    vbo : gl.Buffer,
    program_id : gl.Program,
    ctime, ptime: f64,
    logger : log.Logger,
    game : g.GameState,
    old_input : [g.Buttons]g.ButtonState,
    user_data:  rawptr,
    key_down: [2]bool,
    //play_audio : b32,
    ss: f32,
}


ctx : Context


set_ev :: proc(yes: bool, code : string) {
    if(code == "KeyW" || code == "ArrowUp") {
        ctx.key_down[0] = yes
    } else if(code == "KeyS" || code == "ArrowDown") {
        ctx.key_down[1] = yes
    }
}

event_callback :: proc(e: js.Event) {
	//c := (^Context)(e.user_data)
    context.logger = ctx.logger




	#partial switch e.kind {
	    case .Key_Up:  {
            set_ev(false, e.key.code)
	    }
	    case .Key_Down: {
            set_ev(true, e.key.code)
	   }
	}
}

play_sound2 :: proc() {
    play_sound()
}

@export step :: proc(delta_time: f64) -> (keep_going: bool) {
    using ctx

    ctime = delta_time

    context.logger = logger

    ctx.game.dt = f32(delta_time)
    for oldi, ind in ctx.old_input {
        ctx.game.new_input[ind].ended_down = oldi.ended_down
    }

    ctx.game.new_input[.Move_Up].ended_down = key_down[0]
    ctx.game.new_input[.Move_Down].ended_down = key_down[1]


    sb.vert = make([]Vertex, MAX_QUADS, context.temp_allocator)
    sb.count = 0
    g.sb.sprite = make([]g.Sprite, g.MAX_SPRITES, context.temp_allocator)
    g.sb.size = 0

    g.update(&ctx.game)

    for i : u32 = 0; i < g.sb.size; i += 1 {
        spos := g.sb.sprite[i].pos
        ssize := g.sb.sprite[i].size

        xpos  := (spos.x  / WIDTH) * 2 - 1
        ypos  := (spos.y  / HEIGHT) * 2  - 1
        xsize := ( ssize.x * 2 / WIDTH)
        ysize := ( ssize.y * 2 / HEIGHT)

        atlaspos := g.sb.sprite[i].atlaspos
        atlassize := g.sb.sprite[i].atlas_size

        axpos := atlaspos.x / atlas.SIZE.x
        aypos := atlaspos.y / atlas.SIZE.y
        aysize := atlassize.y / atlas.SIZE.y
        axsize := atlassize.x / atlas.SIZE.x

        ypos = -ypos

        sb.vert[sb.count + 0].pos = {xpos,         ypos,         0}
        sb.vert[sb.count + 1].pos = {xpos,         ypos - ysize, 0}
        sb.vert[sb.count + 2].pos = {xpos + xsize, ypos,         0}
        sb.vert[sb.count + 3].pos = {xpos + xsize, ypos,         0}
        sb.vert[sb.count + 4].pos = {xpos,         ypos - ysize, 0}
        sb.vert[sb.count + 5].pos = {xpos + xsize, ypos - ysize, 0}

        sb.vert[sb.count + 0].tex = atlaspos
        sb.vert[sb.count + 1].tex = {atlaspos.x,  atlaspos.y + atlassize.y}
        sb.vert[sb.count + 2].tex = {atlaspos.x + atlassize.x, atlaspos.y }
        sb.vert[sb.count + 3].tex = {atlaspos.x + atlassize.x, atlaspos.y }
        sb.vert[sb.count + 4].tex = {atlaspos.x,  atlaspos.y + atlassize.y}
        sb.vert[sb.count + 5].tex = atlaspos + atlassize

        sb.vert[sb.count + 0].color = g.sb.sprite[i].color
        sb.vert[sb.count + 1].color = g.sb.sprite[i].color
        sb.vert[sb.count + 2].color = g.sb.sprite[i].color
        sb.vert[sb.count + 3].color = g.sb.sprite[i].color
        sb.vert[sb.count + 4].color = g.sb.sprite[i].color
        sb.vert[sb.count + 5].color = g.sb.sprite[i].color

        sb.count += 6
    }




    gl.BindBuffer(gl.ARRAY_BUFFER, ctx.vbo)
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, sb.count * size_of(Vertex), &sb.vert[0])

    gl.ClearColor(0, 0.1, 0.3, 1.0)
    gl.Clear(u32(gl.COLOR_BUFFER_BIT))
    gl.UseProgram(ctx.program_id)
    gl.BindVertexArray(ctx.vao);
    gl.DrawArrays(gl.TRIANGLES, 0, ctx.sb.count)

    //play_sound()


    if(game.sound_playing) { ctx.ss += f32(delta_time) }

    if ctx.ss > 0.4 {
        ctx.ss = 0
        game.sound_playing = false
    }
    free_all(context.temp_allocator)

    old_input, game.new_input = game.new_input, old_input
    return true
}

main :: proc() {
    context.logger = log.create_console_logger()

    js.add_window_event_listener(.Key_Up, &ctx, event_callback, true)
    js.add_window_event_listener(.Key_Down, &ctx, event_callback, true)


    ctx.logger = context.logger
    _ = gl.CreateCurrentContextById("canvas0", {})
    _ = gl.SetCurrentContextById("canvas0")

    gl.ClearColor(0, 0.1, 0.3, 1.0)
    gl.Clear(u32(gl.COLOR_BUFFER_BIT))

    ctx.program_id, _ = gl.CreateProgramFromStrings({vshader_src}, {fshader_src})

    //js.set_element_key_f64("canvas0", "width", 1280)
    //js.set_element_key_f64("canvas0", "height", 720)

    //js.set_element_key_string("sfx", "autoplay", "true")

    width := js.get_element_key_f64("canvas0", "width")
    log.info("canvas width : ", width)

    height := js.get_element_key_f64("canvas0", "height")
    log.info("canvas height : ", height)
    gl.Viewport(0, 0, gl.DrawingBufferWidth(), gl.DrawingBufferHeight())

    //sb : Batch
    //defer delete(sb.vert)

    //sb.vert = []f32{
    //     0.0,  0.5, 0.0,
    //     0.5, -0.5, 0.0,
    //    -0.5, -0.5, 0.0,
    //}

    ctx.vao = gl.CreateVertexArray()
    //gl.GenBuffers(1, &vbo)
    ctx.vbo = gl.CreateBuffer()

    gl.BindVertexArray(ctx.vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, ctx.vbo)

    gl.BufferData(gl.ARRAY_BUFFER, MAX_QUADS * size_of(Vertex), nil, gl.DYNAMIC_DRAW)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), 0)
    gl.EnableVertexAttribArray(0)

    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, tex))
    gl.EnableVertexAttribArray(1)

    gl.VertexAttribPointer(2, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, color))
    gl.EnableVertexAttribArray(2)

    twidth, theight, nr_channels : i32
    data := stbi.load_from_memory(raw_data(TEXTURE_ATLAS), i32(len(TEXTURE_ATLAS)), &twidth,
                                 &theight, &nr_channels, 0);
    assert(data != nil, "failed loading texture atlas")

    texture := gl.CreateTexture()
    gl.BindTexture(gl.TEXTURE_2D, texture)

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S,  i32(gl.CLAMP_TO_EDGE))	// set texture wrapping to GL_REPEAT (default wrapping method)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T,  i32(gl.CLAMP_TO_EDGE))
    //./// set texturgl.iltering pargl.ters
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, i32(gl.NEAREST))
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, i32(gl.NEAREST))

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, twidth, theight, 0, gl.RGBA,
                  gl.UNSIGNED_BYTE, int(twidth * theight * nr_channels), data)


    stbi.image_free(data)

    atlas_location := gl.GetUniformLocation(ctx.program_id, "atlas")
    gl.Uniform1i(atlas_location, 0)

    ctx.game.screen = {1280, 720}
    g.init_game(&ctx.game)

    ctx.game.play_sound = play_sound2

    ctx.game.p.pos = make([]g.vec2, 10)
    ctx.game.p.dir = make([]g.vec2, 10)
    defer delete(ctx.game.p.pos)
    defer delete(ctx.game.p.dir)



    free_all(context.temp_allocator)


    log.info("Hellope")
}

vshader_src := `#version 300 es

layout (location = 0) in vec3 pos;
layout (location = 1) in vec2 tex;
layout (location = 2) in vec3 color;

out vec3 o_color;
out vec2 uv;

void main() {
    o_color = color;
    uv = tex;
    gl_Position = vec4(pos, 1.0);
}
`

fshader_src := `#version 300 es
precision highp float;

uniform sampler2D atlas;

in vec2 uv;
in vec3 o_color;

out vec4 FragColor;

vec4 clampToBorderTexture(sampler2D ts, vec2 uv, vec4 borderColor){
    vec4 c = texture(ts, uv);
    if((uv.x>1.0f && uv.y > 1.0f) || (uv.x<0.0f && uv.y < 0.0f) ){
    return borderColor;
    }
    return c;
}

void main() {
    ivec2 pixelCoord = ivec2(uv.x, uv.y);
    vec4 pixelValue = texelFetch(atlas, pixelCoord, 0);
    vec4 test = clampToBorderTexture(atlas, uv, vec4(o_color, 1.0f));
    if (pixelValue.w == 0.0f) discard;
    FragColor = test * vec4(o_color, 1.0f);
}
`