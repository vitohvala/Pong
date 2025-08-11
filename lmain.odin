package Pong

import "core:fmt"
import "core:log"
import x "vendor:x11/xlib"
import gl "vendor:OpenGL"
import "core:strings"
import glx "glx"
import "base:runtime"
import "core:mem"
import "core:time"
import v "core:mem/virtual"
import "core:math/linalg"
import stbi "vendor:stb/image"

import g "game"

vec2 :: g.vec2
vec3 :: g.vec3
vec4 :: g.vec4

//sb : SpriteBatch
running := false
gstate : g.GameState


set_size_hints :: proc(display : ^x.Display, window : x.Window,
                      minWidth, minHeight, maxWidth, maxHeight: i32)
{
    hints : x.XSizeHints
    if(minWidth > 0 && minHeight > 0) { hints.flags = { .PMinSize } }
    if(maxWidth > 0 && maxHeight > 0) { hints.flags += { .PMaxSize } }

    hints.min_width = minWidth;
    hints.min_height = minHeight;
    hints.max_width = maxWidth;
    hints.max_height = maxHeight;

    x.SetWMNormalHints(display, window, &hints);
}

hv_messagebox :: #force_inline proc(msg_args : ..any) {
    //TODO make a hv_messagebox for linux
    message := fmt.tprintln(..msg_args)
}

hv_assert ::#force_inline proc(assertion : bool, msg_args : ..any, loc := #caller_location) {
    when ODIN_DISABLE_ASSERT {
    } else {
        message := fmt.tprintln(..msg_args)
        if !assertion {
            log.error(message)
            running = false
        }
    }
}

gl_debug_callback :: proc "c" (source: u32, type: u32, id: u32, severity: u32, length: i32, message: cstring, userParam: rawptr) {
    context = runtime.default_context()
    if(severity == gl.DEBUG_SEVERITY_LOW ||
       severity == gl.DEBUG_SEVERITY_MEDIUM ||
       severity == gl.DEBUG_SEVERITY_HIGH)
    {
        log.error(string(message))
        running = false
    } else {
        log.info(string(message))
    }
}

glx_set_proc_address :: proc(p: rawptr, name: cstring) {
    proc_ptr := glx.GetProcAddress(name)
    (cast(^rawptr)p)^ = cast(rawptr)proc_ptr
}

gl_error :: proc(_id, type_status : u32) -> bool {
    success : i32
    infoLog : [512]u8
    if type_status == gl.LINK_STATUS {
        gl.GetProgramiv(_id, gl.LINK_STATUS, &success);
    } else {
        gl.GetShaderiv(_id, type_status, &success)
    }



    if (success == 0) {
        if type_status == gl.LINK_STATUS {
            gl.GetProgramInfoLog(_id, 512, nil, raw_data(infoLog[:]))
        } else {
            gl.GetShaderInfoLog(_id, 512, nil, raw_data(infoLog[:]))
        }
        infolen := 0
        for c in infoLog {
            if c == 0 { break }
            infolen += 1
        }
        log.errorf("ERROR  ", string(infoLog[:infolen]))
        return false
    }
    return true
}

compile_shader :: proc(source : string, shader_type : u32) -> u32 {
    ret : u32

    ret = gl.CreateShader(shader_type)

    vshader_srcs := [1]cstring{cstring(raw_data(source))}
    gl.ShaderSource(ret, 1, raw_data(vshader_srcs[:]), nil)
    gl.CompileShader(ret)


    running := gl_error(ret, gl.COMPILE_STATUS)

    return ret
}

load_shaders :: proc(vsource, fsource : string) -> (program_id : u32) {
    program_id = gl.CreateProgram()
    vshader := compile_shader(vshader_src, gl.VERTEX_SHADER)
    fshader := compile_shader(fshader_src, gl.FRAGMENT_SHADER)

    gl.AttachShader(program_id, vshader)
    gl.AttachShader(program_id, fshader)
    gl.LinkProgram(program_id)

    running = gl_error(program_id, gl.LINK_STATUS)

    gl.DeleteShader(vshader);
    gl.DeleteShader(fshader);

    //detach shaders????

    return
}


main :: proc() {
    running = true

    when ODIN_DEBUG {
        context.logger = log.create_console_logger(log.Level.Debug,
            { .Level, .Procedure, .Thread_Id })
    }

    persistent : v.Arena
    errf := v.arena_init_static(&persistent)
    assert(errf == .None, "Arena creation failed")
    p_allocator := v.arena_allocator(&persistent);

    log.infof("Persistent arena {}GB reserved", persistent.total_reserved / mem.Gigabyte)


    log.info("Opening X11 window")
    display := x.OpenDisplay(nil)
    hv_assert(display != nil, "Open display failed")

    screen  := x.DefaultScreenOfDisplay(display)
    screen_id := x.DefaultScreen(display)

    visual_attribs := [?]i32 {
        glx.GLX_X_RENDERABLE    , 1,
        glx.GLX_DRAWABLE_TYPE   , glx.GLX_WINDOW_BIT,
        glx.GLX_RENDER_TYPE     , glx.GLX_RGBA_BIT,
        glx.GLX_X_VISUAL_TYPE   , glx.GLX_TRUE_COLOR,
        glx.GLX_RED_SIZE        , 8,
        glx.GLX_GREEN_SIZE      , 8,
        glx.GLX_BLUE_SIZE       , 8,
        glx.GLX_ALPHA_SIZE      , 8,
        glx.GLX_DEPTH_SIZE      , 24,
        glx.GLX_STENCIL_SIZE    , 8,
        glx.GLX_DOUBLEBUFFER    , 1,
        //GLX_SAMPLE_BUFFERS  , 1,
        //GLX_SAMPLES         , 4,
        x.None
    }


    majorx, minorx : int
    glx.QueryVersion(display, &majorx, &minorx)
    if majorx ==1 && minorx < 3 {
        log.warn("glX 1.2 or greater is required")
        running = false
    }

    fb_count : i32
    fbc := glx.ChooseFBConfig(display, screen_id, &visual_attribs[0], &fb_count)
    hv_assert(fbc != nil, "failed to retrieve a framebuffer config")

    log.infof("Found {} matching FB configs", fb_count)

    best_fbc, worst_fbc, best_samp, worst_samp : i32 = -1, -1, -1, 999

    fbc_array := cast([^]glx.GLXFBConfig)fbc
    for i in 0..<fb_count {
        vinfo := glx.GetVisualFromFBConfig(display, fbc_array[i])

        if vinfo != nil {
            samp_buf, samples : i32
            glx.GetFBConfigAttrib(display, fbc_array[i], glx.GLX_SAMPLE_BUFFERS, &samp_buf)
            glx.GetFBConfigAttrib(display, fbc_array[i], glx.GLX_SAMPLES, &samples)

            log.infof("Matching FBConfig {}, visual ID = {}, sample buffers = {}, samples = {}",
                     i, vinfo.visualid, samp_buf, samples)

            if best_fbc < 0 || (samp_buf != 0 && samples > best_samp) {
                best_fbc, best_samp = i, samples
            }
            if worst_fbc < 0 || (samp_buf == 0 && samples < worst_samp) {
                worst_fbc,  worst_samp = i, samples
            }

        }
        x.Free(vinfo)
    }

    bestfbc := fbc_array[best_fbc]

    x.Free(fbc)


    visual := glx.GetVisualFromFBConfig(display, bestfbc)
    hv_assert(visual != nil, "GetVisual failed")

    log.info("chosen visual ID = ", visual.visualid)

    swa := x.XSetWindowAttributes {
        colormap = x.CreateColormap(display, x.RootWindow(display, visual.screen), visual.visual, .AllocNone),
        background_pixmap = x.None,
        border_pixel = 0,
        event_mask = { .StructureNotify, .KeyPress, .KeyRelease, .Exposure }
    }

    window := x.CreateWindow(display, x.RootWindow(display, visual.screen),
                            0, 0, 1280, 720, 0, visual.depth, .InputOutput, visual.visual,
                            { .CWBorderPixel, .CWColormap, .CWEventMask}, &swa)

    hv_assert(window != 0, "failed to create a window")
    set_size_hints(display, window, 1280, 720, 1280, 720)

    WM_DELETE_WINDOW := x.InternAtom(display, "WM_DELETE_WINDOW", false)
    if(x.SetWMProtocols(display, window, &WM_DELETE_WINDOW, 1) == nil) {
        log.error("Couldn't register WM_DELETE_WINDOW property")
    }

    x.Free(visual)

    x.StoreName(display, window, "Pong")

    x.MapWindow(display, window)

    glx_exts := glx.QueryExtensionsString(display, x.DefaultScreen(display))

    glXCreateContextAttribsARB :=
        glx.PFNGLXCREATECONTEXTATTRIBSARBPROC(
            glx.GetProcAddressARB("glXCreateContextAttribsARB"))

    g_ctx : glx.GLXContext

    //todo x error handler



    if !strings.contains(string(glx_exts), "GLX_ARB_create_context")  || glXCreateContextAttribsARB == nil {
        log.info("lXCreateContextAttribsARB() not found")
    } else {
        log.info("Creating context")

      context_attribs := [?]i32 {
        glx.GLX_CONTEXT_MAJOR_VERSION_ARB, 4,
        glx.GLX_CONTEXT_MINOR_VERSION_ARB, 3,
        //GLX_CONTEXT_FLAGS_ARB        , GLX_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB,
        x.None
      }
        g_ctx = glXCreateContextAttribsARB( display, bestfbc, nil,
                                            true, &context_attribs[0] );
        x.Sync(display)

        hv_assert(g_ctx != nil, "Failed to create GL 3.0 context")
    }

    glx.MakeCurrent(display, window, g_ctx)


    gl.load_up_to(4, 3, glx_set_proc_address)

    gl.Viewport(0, 0, 800, 600)

    gl.DebugMessageCallback(gl_debug_callback, nil);
    gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS);
    gl.Enable(gl.DEBUG_OUTPUT);

    //hader_program, ok := gl.load_shaders(vshader_src, fshader_src, true)
    //hv_assert(ok == true, "failed compiling shaders")

    //vertex_shader_id := gl.compile_shader_from_source(vshader_src, .VERTEX_SHADER)

    program_id := load_shaders(vshader_src, fshader_src)

    vao : u32
    gl.GenVertexArrays(1, &vao);

    width, height, nr_channels : i32
    data := stbi.load("assets/atlas.png", &width, &height, &nr_channels, 0);
    hv_assert(data != nil, "failed loading texture atlas")

    texture : u32
    gl.GenTextures(1, &texture);
    gl.ActiveTexture(gl.TEXTURE0);
    gl.BindTexture(gl.TEXTURE_2D, texture);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);	// set texture wrapping to GL_REPEAT (default wrapping method)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER);
    //./// set texturgl.iltering pargl.ters
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, width, height, 0, gl.RGBA,
                 gl.UNSIGNED_BYTE, data);

    //glGenerateMipmap(GL_TEXTURE_2D);
    stbi.image_free(data);

    //glUniform2f(glGetUniformLocation(program_id, "screensize"), 0);

    //gl.Enable(gl.FRAMEBUFFER_SRGB);
    gl.Disable(0x809D);

    gl.UseProgram(program_id)


    sprite_id : u32
    gl.GenBuffers(1, &sprite_id);
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, sprite_id);
    gl.BufferData(gl.SHADER_STORAGE_BUFFER, size_of(g.Sprite) * g.MAX_SPRITES,
                 raw_data(g.sb.sprite), gl.DYNAMIC_DRAW);


    scsize_uloc := gl.GetUniformLocation(program_id, "screensize")

    attribs : x.XWindowAttributes
    x.GetWindowAttributes(display, window, &attribs);

    screensize := vec2 {f32(attribs.width), f32(attribs.height)}
    gl.Uniform2fv(scsize_uloc, 1, &screensize.x)

    gl.Viewport(0, 0, attribs.width, attribs.height)


    gl.Enable(gl.DEPTH_TEST);
    gl.DepthFunc(gl.GREATER);

    gstate.screen = screensize
    g.init_game(&gstate)
    old_input : [g.Buttons]g.ButtonState
    start_tick := time.tick_now()
    tick := start_tick

    gstate.p.pos = make([]vec2, 10, p_allocator)
    gstate.p.dir = make([]vec2, 10, p_allocator)

    for running {
        gstate.dt = f32(time.duration_seconds(time.tick_lap_time(&tick)))

        for oldi, ind in old_input {
            gstate.new_input[ind].ended_down = oldi.ended_down
        }

        if x.Pending(display) > 0 {
            xevent : x.XEvent
            x.NextEvent(display, &xevent)
            #partial switch xevent.type {
                case .KeymapNotify:
                    x.RefreshKeyboardMapping(&xevent.xmapping)
                case .KeyPress: fallthrough
                case .KeyRelease: {
                    key := x.LookupKeysym(&xevent.xkey, 0)
                    is_down := (xevent.type == .KeyPress)
                    was_down := (xevent.type == .KeyRelease)
                    //alt_pressed = (event.xkey.state & (Mod1Mask | Mod5Mask));

                    if (is_down != was_down) {
                        #partial switch key {
                            case .XK_w : fallthrough
                            case .XK_Up : {
                                g.process_keyboard_message(&gstate.new_input[.Move_Up], is_down)
                            }
                            case .XK_s : fallthrough
                            case .XK_Down : {
                                g.process_keyboard_message(&gstate.new_input[.Move_Down], is_down)
                            }
                        }
                    }
                }
                case .ClientMessage: {
                    if (x.Atom(xevent.xclient.data.l[0]) == WM_DELETE_WINDOW) {
                        running = false
                    }
                }
                case .Expose : {
                    log.info("expose event")
                    x.GetWindowAttributes(display, window, &attribs);
                }
            }
        }
        g.sb.sprite = make([]g.Sprite, g.MAX_SPRITES, context.temp_allocator)
        g.sb.size = 0

        g.update(&gstate)

        gl.ClearColor(0, 0.1, 0.3, 1.0)
        gl.ClearDepth(0)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)


        gl.UseProgram(program_id)
        gl.BindVertexArray(vao)

        //gl.ActiveTexture(gl.TEXTURE0);
        //gl.BindTexture(gl.TEXTURE_2D, texture);

        gl.BufferSubData(gl.SHADER_STORAGE_BUFFER, 0, int(size_of(g.Sprite) * g.sb.size),
                          raw_data(g.sb.sprite))

        gl.DrawArraysInstanced(gl.TRIANGLES, 0, 6, i32(g.sb.size));

        glx.SwapBuffers(display, window)

        free_all(context.temp_allocator)
        old_input, gstate.new_input = gstate.new_input, old_input
    }
    v.arena_free_all(&persistent)
    v.arena_destroy(&persistent)

}

vshader_src := `
#version 430 core

uniform vec2 screensize;

struct IDK {
    vec2 pos;
    vec2 size;
};

struct Sprite {
    IDK sprite;
    IDK atlas;
    vec3 color;
};

layout(std430, binding = 0) buffer SpriteBuffer {
    Sprite sprites[];
};

out vec2 uv;
out vec4 vertex_color;

void main() {
    Sprite spr = sprites[gl_InstanceID];
    IDK sprite = spr.sprite;
    IDK atlas = spr.atlas;
    vec3 color = spr.color;

    vec2 vertices[6] = {
        sprite.pos,                                     // Top Left
        vec2(sprite.pos + vec2(0.0, sprite.size.y)),    // Bottom Left
        vec2(sprite.pos + vec2(sprite.size.x, 0.0)),    // Top Right
        vec2(sprite.pos + vec2(sprite.size.x, 0.0)),    // Top Right
        vec2(sprite.pos + vec2(0.0, sprite.size.y)),    // Bottom Left
        sprite.pos + sprite.size                        // Bottom Right
    };

    float left   = atlas.pos.x;
    float top    = atlas.pos.y;
    float right  = (atlas.pos.x + atlas.size.x);
    float bottom = (atlas.pos.y + atlas.size.y);

    vec2 uv_coords[6] = {
        vec2(left, top),
        vec2(left, bottom),
        vec2(right, top),
        vec2(right, top),
        vec2(left, bottom),
        vec2(right, bottom),
    };

    vec2 pos = 2.0f *  (vertices[gl_VertexID] / screensize) - 1.0;
    pos.y = -pos.y;

    gl_Position = vec4(pos.x, pos.y, 0.0, 1.0);
    uv = uv_coords[gl_VertexID];
    vertex_color = vec4(color, 1.0);
}

`

fshader_src := `
#version 430 core
layout(location = 0) uniform sampler2D atlastexture;

in vec2 uv;
in vec4 vertex_color;

out vec4 FragColor;

void main() {
    //vec4 color = texture(atlastexture, uv);
    vec4 color = texelFetch(atlastexture, ivec2(uv), 0);
    if (color.a == 0.0) discard;
    FragColor = color * vertex_color;
}

`