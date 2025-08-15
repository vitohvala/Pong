package Pong

/* TODO :
        Linux and opengl/vulkan ????
        WebGL ????
*/


import "core:fmt"
import win "core:sys/windows"
import "core:slice"
import "core:mem"
import v "core:mem/virtual"
import "core:os"
import "core:strings"
import "base:runtime"
import "core:log"
import "core:time"
import "core:math"
import "core:math/rand"
import "core:math/linalg"
import d11 "vendor:directx/d3d11"
import dxgi "vendor:directx/dxgi"
import d3d  "vendor:directx/d3d_compiler"
import xa "vendor:windows/XAudio2"
import stbi "vendor:stb/image" //remove this


import atlas "atlas"

import g "game"

texture_atlas :: #load("assets/atlas.png")
SFX_SOUND :: #load("assets/sfx.wav")

/*===============================================================================
                                        STRUCTS
  ===============================================================================*/

vec2 :: [2]f32
vec3 :: [3]f32
vec4 :: [4]f32


XSound :: struct {
    mvoice : ^xa.IXAudio2MasteringVoice,
    srcvoice : ^xa.IXAudio2SourceVoice,
    volume : f32,
}

GSound :: struct {
    wvf : win.WAVEFORMATEX,
    data : xa.BUFFER,
    xaudio : ^xa.IXAudio2,
    sfx : XSound,
    music : XSound,
}

DxData :: struct {
    device : ^d11.IDevice,
    dcontext: ^d11.IDeviceContext,
    framebuffer_rtv: ^d11.IRenderTargetView,
    swapchain : ^dxgi.ISwapChain4,
    viewport : d11.VIEWPORT,
    vertex_shader : ^d11.IVertexShader,
    pixel_shader :  ^d11.IPixelShader,
    sprite_SRV : ^d11.IShaderResourceView,
    sprite_buffer : ^d11.IBuffer,
    rstate : ^d11.IRasterizerState,
    atlas_SRV : ^d11.IShaderResourceView,
    sampler : ^d11.ISamplerState,
    constant_data : g.Constants,
    constant_buffer : ^d11.IBuffer,
}

/*===============================================================================
                                        GLOBALS
  ===============================================================================*/

running := false
sb : ^g.SpriteBatch
gsound : GSound

/*===============================================================================
                                      PROCEDURES
  ===============================================================================*/
win_proc :: proc "stdcall" (hwnd: win.HWND,
    msg: win.UINT,
    wparam: win.WPARAM,
    lparam: win.LPARAM) -> win.LRESULT
{
    context = runtime.default_context()
    switch msg {
        case win.WM_CLOSE :
            running = false
        fallthrough
        case win.WM_DESTROY :
            running = false
        win.PostQuitMessage(0)
        return 0
        case win.WM_ERASEBKGND : return 1
        case win.WM_SIZE : {
            crect :win.RECT
            win.GetClientRect(hwnd, &crect)
        }
        case win.WM_NCLBUTTONDOWN:
        {
            //log.info("NCLBUTTONDOWN")
            win.SendMessageW(hwnd, win.WM_NCHITTEST, wparam, lparam)
            point : win.POINT
            win.GetCursorPos(&point)
            win.ScreenToClient(hwnd, &point)
            win.PostMessageW(hwnd, win.WM_MOUSEMOVE, 0, int(point.x | point.y << 16))
        }
        case win.WM_ENTERSIZEMOVE : { win.SetTimer(hwnd, 1, 0, nil); return 0}
        case win.WM_EXITSIZEMOVE : { win.KillTimer(hwnd, 1); return 0 }
        case win.WM_TIMER : {
            //update
            return 0
        }
        case win.WM_PAINT:
        {
            pst : win.PAINTSTRUCT
            win.BeginPaint(hwnd, &pst)

            win.EndPaint(hwnd, &pst)
        }
        case win.WM_SYSKEYDOWN :
        case win.WM_SYSKEYUP :
        case win.WM_KEYDOWN :
        case win.WM_KEYUP : {

        }

    }

    return win.DefWindowProcW(hwnd, msg, wparam, lparam)
}

hv_messagebox :: #force_inline proc (s : string) {
    win.MessageBoxW(nil, win.utf8_to_wstring(s), win.L("FATAL"),
                    win.MB_OK | win.MB_ICONERROR)
}

hv_assert :: #force_inline proc(assertion: bool, msg_args : ..any, loc := #caller_location)
{
    when ODIN_DISABLE_ASSERT {
        if !assertion {
            //context = runtime.default_context()

            lp_msg_buf : win.wstring
            dw := win.GetLastError()
            message := fmt.tprint(..msg_args)

            lp_len := win.FormatMessageW(win.FORMAT_MESSAGE_ALLOCATE_BUFFER |
                              win.FORMAT_MESSAGE_FROM_SYSTEM |
                              win.FORMAT_MESSAGE_IGNORE_INSERTS,
                              nil, win.GetLastError(),
                              win.MAKELANGID(win.LANG_NEUTRAL, win.SUBLANG_DEFAULT),
                              lp_msg_buf, 0, nil)

            if(lp_len == 0) {
                //errstr := fmt.tprint(..msg_args)
                hv_messagebox(message)
                win.ExitProcess(dw)
                //running = false
            }

            err_msg_str, err_ := win.wstring_to_utf8(lp_msg_buf, int(lp_len))

            if int(err_) > 0 {
                enum_str, _ := fmt.enum_value_to_string(err_)
                hv_messagebox(enum_str)
                running = false
            }

            a := [?]string { err_msg_str, message }
            errstr := strings.concatenate(a[:])

            hv_messagebox(errstr)

            win.LocalFree(lp_msg_buf)

            running = false
        }
    } else {
        if !assertion {
            message := fmt.tprintln(..msg_args)

            assert(assertion, message)

            running = false
        }
    }
}

create_window :: proc(width, height : i32, window_name : string) -> win.HWND {
    instance := win.HINSTANCE(win.GetModuleHandleW(nil))
    assert(instance != nil)

    wca : win.WNDCLASSW
    wca.hInstance = instance
    wca.lpszClassName = win.L("Odin ROCKS")
    wca.style = win.CS_HREDRAW | win.CS_VREDRAW | win.CS_OWNDC
    wca.lpfnWndProc = win_proc
    wca.hIcon = win.LoadIconW(nil, transmute(win.wstring)(win.IDI_APPLICATION))
    wca.hCursor = win.LoadCursorW(nil, transmute(win.wstring)(win.IDC_ARROW))

    cls := win.RegisterClassW(&wca)
    assert(cls != 0, "Class creation failed")

    wrect := win.RECT{0, 0, width, height}
    win.AdjustWindowRect(&wrect, win.WS_OVERLAPPEDWINDOW, win.FALSE)


    window_name_wstring := win.utf8_to_wstring(window_name)

    handle := win.CreateWindowExW(0, wca.lpszClassName,
        window_name_wstring,
        win.WS_OVERLAPPEDWINDOW,
        10, 10,
        wrect.right - wrect.left, wrect.bottom - wrect.top,
        nil, nil, instance, nil)

    assert(handle != nil, "Window Creation Failed\n")

    log.info("Created window", window_name);
    return handle
}

compile_shader :: proc(entrypoint, shader_model : cstring,
                       blob_out : ^^d11.IBlob) -> win.HRESULT
{
    hr : win.HRESULT = win.S_OK
    // WARNINGS_ARE_ERRORS on release
    dw_shader_flags := d3d.D3DCOMPILE { .ENABLE_STRICTNESS, .PACK_MATRIX_COLUMN_MAJOR,  }
    when ODIN_DEBUG {
        dw_shader_flags += { .DEBUG, .SKIP_OPTIMIZATION }
    } else {
        dw_shader_flags += { .OPTIMIZATION_LEVEL3 }
    }

    error_blob : ^d11.IBlob
    hr = d3d.Compile(raw_data(shaders_hlsl), len(shaders_hlsl), "shaders.hlsl", nil, nil, entrypoint,
                     shader_model, 0, 0, blob_out, &error_blob)

    //should i assert this??
    if error_blob != nil {
        buffer_ptr := error_blob->GetBufferPointer()
        bytes := cast([^]u8)buffer_ptr
        err_str8 := string(bytes[:error_blob->GetBufferSize()])
        hv_assert(win.SUCCEEDED(hr), err_str8)
    }

    if (error_blob != nil) { error_blob->Release() }

    return hr
}

init_d3d :: proc(handle : win.HWND) -> DxData {
    d : DxData
    {
        feature_levels := [?]d11.FEATURE_LEVEL{._11_0}


        //RELASE these
        base_device : ^d11.IDevice
        base_device_context : ^d11.IDeviceContext

        creation_flags := d11.CREATE_DEVICE_FLAGS { .BGRA_SUPPORT }

        when ODIN_DEBUG {
            creation_flags += { .DEBUG }
        }

        res := d11.CreateDevice(nil, .HARDWARE, nil, creation_flags,
            &feature_levels[0], len(feature_levels),
            d11.SDK_VERSION, &base_device, nil,
            &base_device_context)

        hv_assert(win.SUCCEEDED(res), string("CreateDevice() failed"))
        //maybe do something where on release it just does MessageBox on error
        //return false

        when ODIN_DEBUG {
            debug : ^d11.IDebug
            base_device->QueryInterface(d11.IDebug_UUID, (^rawptr)(&debug))

            assert(debug != nil)

            info_queue : ^d11.IInfoQueue

            res = debug->QueryInterface(d11.IInfoQueue_UUID, (^rawptr)(&info_queue))

            hv_assert(win.SUCCEEDED(res), string("No debug:(("))

            info_queue->SetBreakOnSeverity(.CORRUPTION, true)
            info_queue->SetBreakOnSeverity(.ERROR, true)

            allow_severities := []d11.MESSAGE_SEVERITY{.CORRUPTION, .ERROR, .INFO}

            filter := d11.INFO_QUEUE_FILTER {
                AllowList = {
                    NumSeverities = u32(len(allow_severities)),
                    pSeverityList = raw_data(allow_severities),
                },
            }
            info_queue->AddStorageFilterEntries(&filter)
            info_queue->Release()

            debug->Release()

            //TODO: make one for dxgi??
            //  IDXGIInfoQueue* dxgiInfo;
            //  hr = DXGIGetDebugInterface1(0, &IID_IDXGIInfoQueue, (void**)&dxgiInfo);
            //  AssertHR(hr);
            //  IDXGIInfoQueue_SetBreakOnSeverity(dxgiInfo, DXGI_DEBUG_ALL, DXGI_INFO_QUEUE_MESSAGE_SEVERITY_CORRUPTION, TRUE);
            //  IDXGIInfoQueue_SetBreakOnSeverity(dxgiInfo, DXGI_DEBUG_ALL, DXGI_INFO_QUEUE_MESSAGE_SEVERITY_ERROR, TRUE);
            //  IDXGIInfoQueue_Release(dxgiInfo);
        }



        res = base_device->QueryInterface(d11.IDevice_UUID, (^rawptr)(&d.device))
        hv_assert(win.SUCCEEDED(res), string("D3D11 device interface query failed"))

        res = base_device_context->QueryInterface(d11.IDeviceContext_UUID,
            (^rawptr)(&d.dcontext))
        hv_assert(win.SUCCEEDED(res), string("D3D11 device context interface query failed"))

        //Maybe just use defer
        base_device_context->Release()
        base_device->Release()

        dxgi_device: ^dxgi.IDevice
        res = d.device->QueryInterface(dxgi.IDevice_UUID, (^rawptr)(&dxgi_device))
        hv_assert(win.SUCCEEDED(res), string("DXGI device interface query failed"))

        dxgi_adapter: ^dxgi.IAdapter
        res = dxgi_device->GetAdapter(&dxgi_adapter)
        hv_assert(win.SUCCEEDED(res), string("DXGI Adapter interface query failed"))

        adapter_desc : dxgi.ADAPTER_DESC
        dxgi_adapter->GetDesc(&adapter_desc)
        graphics_card_buf : [128]u8
        graphics_card := win.utf16_to_utf8(graphics_card_buf[:], adapter_desc.Description[:])
        log.infof("Graphics device : {}", graphics_card )

        dxgi_factory: ^dxgi.IFactory2
        res = dxgi_adapter->GetParent(dxgi.IFactory2_UUID, (^rawptr)(&dxgi_factory))
        hv_assert(win.SUCCEEDED(res), string("Get DXGI Factory failed"))

        dxgi_adapter->Release()
        dxgi_device->Release()


        swapchain_desc := dxgi.SWAP_CHAIN_DESC1{
            Width  = 0,
            Height = 0,
            Format = .B8G8R8A8_UNORM,
            Stereo = false,
            SampleDesc = {
                Count   = 1,
                Quality = 0,
            },
            BufferUsage = { .RENDER_TARGET_OUTPUT } ,
            BufferCount = 2,
            Scaling     = .STRETCH,
            SwapEffect  =  .DISCARD,
            AlphaMode   = .UNSPECIFIED,
            Flags       = {},
        }

        samplec : u32 = 8
        pnql : u32 = 0
        d.device->CheckMultisampleQualityLevels(swapchain_desc.Format, samplec, &pnql)

        if pnql == 0 {
            samplec = 1
            pnql = 1
        }

        swapchain_desc.SampleDesc.Count = samplec
        swapchain_desc.SampleDesc.Quality = pnql - 1

        log.infof("Multisample {}x", samplec)

        swapchain: ^dxgi.ISwapChain1
        res = dxgi_factory->CreateSwapChainForHwnd(d.device, handle, &swapchain_desc, nil, nil, &swapchain)
        hv_assert(win.SUCCEEDED(res), string("CreateSwapChain Failed"))

        // disable silly Alt+Enter changing monitor resolution to match window size
        dxgi_factory->MakeWindowAssociation(handle, { .NO_ALT_ENTER })

        dxgi_factory->Release()

        swapchain->QueryInterface(dxgi.ISwapChain4_UUID, (^rawptr)(&d.swapchain))
        hv_assert(win.SUCCEEDED(res), string("Swapchain4 query interface failed"))

        swapchain->Release()

        framebuffer: ^d11.ITexture2D
        res = d.swapchain->GetBuffer(0, d11.ITexture2D_UUID, (^rawptr)(&framebuffer))
        hv_assert(win.SUCCEEDED(res), string("GetBuffer failed"))

        res = d.device->CreateRenderTargetView(framebuffer, nil, &d.framebuffer_rtv)
        hv_assert(win.SUCCEEDED(res), string("CreateRenderTargetView failed"))

        framebuffer->Release()

        d.dcontext->OMSetRenderTargets(1, &d.framebuffer_rtv, nil)

        {
            swapchain_temp_desc : dxgi.SWAP_CHAIN_DESC1
            d.swapchain->GetDesc1(&swapchain_temp_desc)
            d.viewport.Width = f32(swapchain_temp_desc.Width)
            d.viewport.Height = f32(swapchain_temp_desc.Height)
            d.viewport.MaxDepth = 1
            //since in odin everything is initialized to 0 i dont need to specify other things
            d.dcontext->RSSetViewports(1, &d.viewport)
            log.infof("Swapchain window width {}", swapchain_temp_desc.Width)
            log.infof("Swapchain window Height {}", swapchain_temp_desc.Height)

        }

        vs_blob : ^d11.IBlob

        //TODO: precompile shaders
        compile_shader("vs_main", "vs_5_0", &vs_blob)


        res = d.device->CreateVertexShader(vs_blob->GetBufferPointer(), vs_blob->GetBufferSize(), nil, &d.vertex_shader)
        hv_assert(win.SUCCEEDED(res), string("CreateVertexShader failed"))


        vs_blob->Release()

        ps_blob : ^d11.IBlob
        compile_shader("ps_main", "ps_5_0", &ps_blob)

        res = d.device->CreatePixelShader(ps_blob->GetBufferPointer(), ps_blob->GetBufferSize(), nil, &d.pixel_shader)
        hv_assert(win.SUCCEEDED(res), string("CreatePixelShader failed"))

        ps_blob->Release()

        rdesc := d11.RASTERIZER_DESC {
            FillMode = .SOLID,
            CullMode = .NONE,
            FrontCounterClockwise = false,
            DepthClipEnable = true,
            MultisampleEnable = true,
            AntialiasedLineEnable = true,
            ScissorEnable = false
        }

        res =  d.device->CreateRasterizerState(&rdesc, &d.rstate)
        hv_assert(win.SUCCEEDED(res), string("CreateRasterizerState failed"))

        twidth, theight, nr_channels : i32
        image_data := stbi.load_from_memory(raw_data(texture_atlas), i32(len(texture_atlas)), &twidth, &theight, &nr_channels, 4)
        hv_assert(image_data != nil, string("Image data is null"))

        texture_desc := d11.TEXTURE2D_DESC{
            Width      = u32(twidth),
            Height     = u32(theight),
            MipLevels  = 1,
            ArraySize  = 1,
            Format     = .R8G8B8A8_UNORM,
            SampleDesc = {Count = 1},
            Usage      = .IMMUTABLE,
            BindFlags  = {.SHADER_RESOURCE},
        }

        texture_data := d11.SUBRESOURCE_DATA{
            pSysMem     = &image_data[0],
            SysMemPitch = u32(twidth * 4),
        }

        texture : ^d11.ITexture2D
        res = d.device->CreateTexture2D(&texture_desc, &texture_data, &texture)
        hv_assert(win.SUCCEEDED(res), string("CreateTexture2D failed"))

        d.device->CreateShaderResourceView(texture, nil, &d.atlas_SRV)
        hv_assert(win.SUCCEEDED(res), string("CreateShaderResourceView failed"))

        texture->Release()
        stbi.image_free(image_data)


        sprite_buffer_desc := d11.BUFFER_DESC {
            ByteWidth           = g.MAX_SPRITES * size_of(g.Sprite),
            Usage               = .DYNAMIC,
            BindFlags           = { .SHADER_RESOURCE },
            CPUAccessFlags      = { .WRITE },
            MiscFlags           = { .BUFFER_STRUCTURED },
            StructureByteStride = size_of(g.Sprite),
        }

        d.device->CreateBuffer(&sprite_buffer_desc, nil, &d.sprite_buffer)

        sprite_SRV_desc  := d11.SHADER_RESOURCE_VIEW_DESC {
            Format             = .UNKNOWN,
            ViewDimension      = .BUFFER,
        }
        sprite_SRV_desc.Buffer.NumElements = g.MAX_SPRITES

        d.device->CreateShaderResourceView(d.sprite_buffer, &sprite_SRV_desc, &d.sprite_SRV);

        sampler_desc := d11.SAMPLER_DESC {
            AddressU = .CLAMP,
            AddressV = .CLAMP,
            AddressW = .CLAMP,
            ComparisonFunc = .NEVER,
            Filter = .MIN_MAG_MIP_POINT,
        }

        d.device->CreateSamplerState(&sampler_desc, &d.sampler)
        hv_assert(win.SUCCEEDED(res), string("CreateSamplerState failed"))

        log.info("D3D11 initialization complete;")
    }

    d.constant_data = g.Constants {
        screensize = { d.viewport.Width, d.viewport.Height },
        atlassize =  { atlas.SIZE.x, atlas.SIZE.y },
    }


    constant_buffer_desc := d11.BUFFER_DESC{
        ByteWidth      = size_of(g.Constants),
        Usage          = .IMMUTABLE,
        BindFlags      = {.CONSTANT_BUFFER},
        //	CPUAccessFlags = {.WRITE},
    }
    //constant_buffer: ^d11.IBuffer
    constantSRD := d11.SUBRESOURCE_DATA {
        pSysMem     = &d.constant_data,
    }
    d.device->CreateBuffer(&constant_buffer_desc, &constantSRD, &d.constant_buffer)

    return d
}

start_drawing :: proc() {
    sb.sprite = make([]g.Sprite, g.MAX_SPRITES, context.temp_allocator)
    sb.size = 0
}

end_drawing :: proc(using d : ^DxData) {
    sprite_buffer_MSR : d11.MAPPED_SUBRESOURCE

    dcontext->Map(sprite_buffer, 0, .WRITE_DISCARD, nil, &sprite_buffer_MSR)
    {
        mem.copy(sprite_buffer_MSR.pData, raw_data(sb.sprite),
                 size_of(g.Sprite) * int(sb.size))
    }

    dcontext->Unmap(sprite_buffer, 0)

    dcontext->ClearRenderTargetView(framebuffer_rtv, &[4]f32{0, 0.1, 0.3, 1})

    //stride : u32 = 3 * 4
    //offset := u32(0)

    //dcontext->IASetVertexBuffers(0, 1, &vertex_buffer, &stride, &offset)
    dcontext->IASetPrimitiveTopology(.TRIANGLELIST)

    dcontext->RSSetState(rstate)

    dcontext->VSSetShader(vertex_shader, nil, 0)
    dcontext->VSSetShaderResources(0, 1, &sprite_SRV);
    dcontext->VSSetConstantBuffers(0, 1, &constant_buffer);
    dcontext->PSSetShader(pixel_shader, nil, 0)
    dcontext->PSSetShaderResources(1, 1, &atlas_SRV)
    dcontext->PSSetSamplers(0, 1, &sampler)

    dcontext->DrawInstanced(6, sb.size, 0, 0)
    swapchain->Present(1, {})
}

init_sound :: proc(alloc : runtime.Allocator) -> GSound{
    gs : GSound
    log.info("Initializing Xaudio2")

    gs.sfx.volume = 1.0
    gs.music.volume = 1.0

    res := win.CoInitializeEx(nil, .MULTITHREADED)
    assert(res == win.S_OK, "CoinitializeEx failed")

    res = xa.Create(&gs.xaudio)
    assert(res == win.S_OK, "Xaudio2Create failed")

    res = gs.xaudio->CreateMasteringVoice(&gs.sfx.mvoice)
    assert(res == win.S_OK, "CreateMasteringVoice failed")

    wv := win.WAVEFORMATEX {
        wFormatTag = win.WAVE_FORMAT_PCM,
        nChannels = 1, // mono
        nSamplesPerSec = 44100,
        wBitsPerSample = 16,
    }
    wv.nBlockAlign = wv.nChannels * 2
    wv.nAvgBytesPerSec = wv.nSamplesPerSec * u32(wv.nChannels) * 2

    res = gs.xaudio->CreateSourceVoice(&gs.sfx.srcvoice, &wv)
    assert(res == win.S_OK, "CreateSourceVoice failed")

    res = gs.sfx.srcvoice->SetVolume(gs.sfx.volume)
    assert(res == win.S_OK, "SetVolume failed")

    wav := SFX_SOUND
    riff_header := cast(^[4]u8)&wav[0]
    riff__h := [4]u8{ 0x52, 0x49, 0x46, 0x46 };
    hv_assert(riff__h  == (riff_header^), "not riff - from memory")

    wvf : win.WAVEFORMATEX
    mem.copy(&gs.wvf, &wav[20], size_of(win.WAVEFORMATEX))

    hv_assert((gs.wvf.nBlockAlign == (gs.wvf.nChannels *
               gs.wvf.wBitsPerSample) / 8) ||
               gs.wvf.wFormatTag == win.WAVE_FORMAT_PCM ||
               gs.wvf.wBitsPerSample == 16,  "Sound Data Type Mismatch")

    data_chunk_s := cast(^[4]u8)&wav[36]
    riff__h = [4]u8{ 0x64, 0x61, 0x74, 0x61 };
    hv_assert(riff__h  == (data_chunk_s^), "data not found - from memory")

    data_chunk_size :=  (cast(^u32)&wav[40])^

    gs.data.pAudioData = make([^]u8, data_chunk_size, alloc)
    gs.data.Flags = { .END_OF_STREAM }
    gs.data.AudioBytes = data_chunk_size

    gs.data.pAudioData = raw_data(wav[44:44 + data_chunk_size])

    log.info("Initialized Xaudio2")
    free_all(context.temp_allocator)

    return gs
}

play_sound :: proc() {
    gsound.sfx.srcvoice->SubmitSourceBuffer(&gsound.data)
    gsound.sfx.srcvoice->Start()
}

main :: proc() {
    running = true

    when ODIN_DEBUG {
        context.logger = log.create_console_logger(log.Level.Debug,
                        { .Level, .Procedure, .Terminal_Color, .Thread_Id })
    }

    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    defer mem.tracking_allocator_destroy(&track)
    context.allocator = mem.tracking_allocator(&track)

    persistent : v.Arena
    errf := v.arena_init_static(&persistent)
    assert(errf == .None, "Arena creation failed")
    p_allocator := v.arena_allocator(&persistent);

    log.infof("Persistent arena {}GB reserved", persistent.total_reserved / mem.Gigabyte)

    handle := create_window(1280, 720, "Pong")

    //hv_assert(1 == 2, "Couldntstring(")
    log.info("Initializing d3d11")

    render := init_d3d(handle)

    gsound = init_sound(p_allocator)

    if running {
        win.ShowWindow(handle, win.SW_SHOW)
    }

    start_tick := time.tick_now()
    tick := start_tick

    gstate : g.GameState
    gstate.screen = vec2{render.viewport.Width, render.viewport.Height}
    g.init_game(&gstate)

    old_input : [g.Buttons]g.ButtonState

    gstate.sound_playing = false
    sound_play_s :f32= 0
    gstate.play_sound = play_sound

    log.info("Entering Main Loop")

    //p : Particle
    gstate.p.pos = make([]vec2, 10, p_allocator)
    gstate.p.dir = make([]vec2, 10, p_allocator)

    for running {
        gstate.dt = f32(time.duration_seconds(time.tick_lap_time(&tick)))

        for oldi, ind in old_input {
            gstate.new_input[ind].ended_down = oldi.ended_down
        }

        msg : win.MSG
        for win.PeekMessageW(&msg, nil, 0, 0, win.PM_REMOVE) {
            vk_code := msg.wParam
            switch msg.message {
                case win.WM_QUIT : running = false;
                case win.WM_KEYUP :  fallthrough
                case win.WM_SYSKEYUP : fallthrough
                case win.WM_SYSKEYDOWN : fallthrough
                case win.WM_KEYDOWN : {
                    was_down := ((msg.lParam & (1 << 30)) != 0)
                    is_down  := ((msg.lParam & (1 << 31)) == 0)

                    if(is_down != was_down) {
                        switch vk_code {
                            case 'W' : fallthrough
                            case win.VK_UP :
                                g.process_keyboard_message(&gstate.new_input[.Move_Up],
                                                         is_down)
                            case 'S' : fallthrough
                            case win.VK_DOWN :
                                g.process_keyboard_message(&gstate.new_input[.Move_Down],
                                                         is_down)
                        }
                    }

                }
                case : {
                    win.TranslateMessage(&msg)
                    win.DispatchMessageW(&msg)
                }
            }
        }

        for xindex in 0..<win.XUSER_MAX_COUNT {
            controller_state : win.XINPUT_STATE
            if win.XInputGetState(nil, &controller_state) == .SUCCESS {
                //pad := &controller_state.Gamepad
            }
        }
        sb = &g.sb
        start_drawing()

        g.update(&gstate)

        end_drawing(&render)

        sound_play_s += gstate.dt

        if(sound_play_s > 0.4) {
            sound_play_s = 0
            gstate.sound_playing = false
        }

        old_input, gstate.new_input = gstate.new_input, old_input

        free_all(context.temp_allocator)
    }

    gsound.xaudio->Release()
    win.CoUninitialize()
    //vertex_buffer->Release()
    //input_layout->Release()
    render.sprite_SRV->Release()
    render.sprite_buffer->Release()
    render.rstate->Release()
    render.atlas_SRV->Release()
    render.sampler->Release()

    render.constant_buffer->Release()

    render.pixel_shader->Release()
    render.vertex_shader->Release()

    render.swapchain->Release()
    render.framebuffer_rtv->Release()
    render.dcontext->Release()
    render.device->Release()

    v.arena_free_all(&persistent)
    free_all(context.temp_allocator)
    for _, value in track.allocation_map {
        fmt.printf("%v leaked %v bytes", value.location, value.size)
    }
    v.arena_destroy(&persistent)
}


// SV_INSTANCEID, SV_VERTEXID
shaders_hlsl := `

cbuffer constants : register(b0)
{
    float2 screensize;
    float2 atlassize;
}

struct vout {
    float4 position : SV_POSITION;
    float2 uv : UV;
    float4 color : COLOR;
};

struct vin {
    uint vertex_id : SV_VERTEXID;
    uint inst_id : SV_INSTANCEID;
};

struct IDK {
    float2 pos;
    float2 size;
};

struct Sprite {
    IDK sprite;
    IDK atlas;
    float3 color;
};

//copied from https://gist.github.com/d7samurai/8f91f0343c411286373161202c199b5c
StructuredBuffer<Sprite> spritebuffer : register(t0);
Texture2D<float4>        atlastexture : register(t1);

SamplerState             pointsampler : register(s0);

vout vs_main(vin input) {
    vout output;

    Sprite spr = spritebuffer[input.inst_id];
    IDK sprite = spr.sprite;
    IDK atlas = spr.atlas;
    float3 color = spr.color;

    float2 vertices[6]  = {
        sprite.pos,
        sprite.pos + float2(sprite.size.x, 0.0),
        sprite.pos + float2(0.0, sprite.size.y),
        sprite.pos + float2(0.0, sprite.size.y),
        sprite.pos + float2(sprite.size.x, 0.0),
        sprite.pos + sprite.size,
    };
    float2 pos = (vertices[input.vertex_id] / screensize) * 2 - 1;
    pos.y = -pos.y;

    float4 texpos;

    texpos.x = atlas.pos.x / atlassize.x;
    texpos.y = (atlas.pos.x + atlas.size.x) / atlassize.x;
    texpos.z = atlas.pos.y / atlassize.y;
    texpos.w = (atlas.pos.y + atlas.size.y) / atlassize.y;

    float2 uv[6] = {
        float2(texpos.x, texpos.z),  // top left
        float2(texpos.y, texpos.z),  // top right
        float2(texpos.x, texpos.w),  // bottom left
        float2(texpos.x, texpos.w),  // bottom left
        float2(texpos.y, texpos.z),  // top right
        float2(texpos.y, texpos.w)   // bottom right
    };



    output.position = float4(pos.x, pos.y, 0, 1);
  //  output.color = float4(colors[vertex_ID], 1.0f);
    output.uv = uv[input.vertex_id];
    output.color = float4(color, 1.0f);
    return output;
}
float4 ps_main(vout input) : SV_TARGET {
    float4 color = atlastexture.Sample(pointsampler, input.uv);
    if (color.a == 0) discard;
    return color * input.color;
}`
