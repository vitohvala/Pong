/*
 * Mesa 3-D graphics library
 *
 * Copyright (C) 1999-2006  Brian Paul   All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */
package glx

import x "vendor:x11/xlib"

//using x
//#include <GL/gl.h>


//#if defined(USE_MGL_NAMESPACE)
//#include "glx_mangle.h"
//#endif


//#ifdef __cplusplus
//extern "C" {
//#endif


Display :: x.Display
Window :: x.Window
XID :: x.XID
XVisualInfo :: x.XVisualInfo
Pixmap :: x.Pixmap
Font :: x.Font
Drawable :: x.Drawable

foreign import glx "system:GL"
@(default_calling_convention="c", link_prefix="glX")

foreign glx {
    ChooseVisual :: proc(dpy : ^Display, screen: int, attribList: ^int) -> ^XVisualInfo ---
    CreateContext :: proc(dpy: ^Display, vis: ^XVisualInfo, shareList : GLXContext, direct: bool) -> GLXContext ---
    DestroyContext :: proc(dpy : ^Display, ctx: GLXContext) ---
    MakeCurrent :: proc(dpy: ^Display, drawable: GLXDrawable, ctx : GLXContext) -> bool ---
    CopyContext :: proc(dpy: ^Display, src, dst: GLXContext, mask: uint) ---
    SwapBuffers :: proc(dpy: ^Display, drawable: GLXDrawable) ---
    CreateGLXPixmap :: proc(dpy: ^Display, visual: ^XVisualInfo, pixmap: Pixmap ) -> GLXPixmap ---
    DestroyGLXPixmap :: proc(dpy: ^Display, pixmap: GLXPixmap) ---
    QueryExtension :: proc(dpy: ^Display, errorb, event: ^i32) -> bool ---
    QueryVersion :: proc(dpy: ^Display, maj,min: ^int ) -> bool ---
    IsDirect :: proc(dpy: ^Display, ctx: GLXContext) -> bool ---
    GetConfig :: proc(dpy: ^Display, visual: XVisualInfo, attrib: int, value: ^int) -> int ---
    GetCurrentContext :: proc() -> GLXContext ---
    GetCurrentDrawable :: proc() -> GLXDrawable ---
    WaitGL :: proc() ---
    WaitX :: proc() ---
    UseXFont :: proc(font: Font, first, count, list: int) ---

    /* GLX 1.1 and later */
    QueryExtensionsString :: proc(dpy: ^Display, screen: i32) -> cstring ---
    QueryServerString :: proc(dpy: ^Display, screen, name: int) -> cstring ---
    XGetClientString :: proc(dpy: ^Display, name: int) -> cstring ---


    /* GLX 1.2 and later */
    GetCurrentDisplay :: proc() -> Display ---


    /* GLX 1.3 and later */
    ChooseFBConfig :: proc(dpy: ^Display, screen: i32, attribList, nitems: ^i32) -> ^GLXFBConfig ---
    GetFBConfigAttrib :: proc(dpy: ^Display, config: GLXFBConfig, attribute: i32, value: ^i32) -> int ---
    GetFBConfigs :: proc(dpy, screen: int, nelements: int) -> ^GLXFBConfig ---
    GetVisualFromFBConfig :: proc(dpy: ^Display, config: GLXFBConfig) -> ^XVisualInfo ---
    CreateWindow :: proc(dpy: ^Display, config: GLXFBConfig, win: Window, attribList: ^int) -> GLXWindow ---
    DestroyWindow :: proc(dpy: ^Display, window: GLXWindow) ---
    CreatePixmap :: proc(dpy: ^Display, config: GLXFBConfig, pixmap: Pixmap, attribList: ^int) -> GLXPixmap ---
    DestroyPixmap :: proc(dpy: ^Display, pixmap: GLXPixmap) ---
    CreatePbuffer :: proc(dpy: ^Display, config: GLXFBConfig, attribList: ^int) -> GLXPbuffer ---
    DestroyPbuffer :: proc(dpy: ^Display, pbuf: GLXPbuffer) ---
    QueryDrawable :: proc(dpy: ^Display, draw: GLXDrawable, attribute: int, value: ^int) ---
    CreateNewContext :: proc(dpy: ^Display, config: GLXFBConfig, renderType: int, shareList: GLXContext, direct: bool) -> GLXContext ---
    MakeContextCurrent :: proc(dpy: ^Display, draw, read: GLXDrawable, ctx: GLXContext) -> bool ---
    GetCurrentReadDrawable :: proc() -> GLXDrawable ---
    QueryContext :: proc(dpy: ^Display, ctx: GLXContext, attribute: int, value: ^int) -> int ---
    SelectEvent :: proc(dpy: ^Display, drawable: GLXDrawable, mask: uint) ---
    GetSelectedEvent :: proc(dpy: ^Display, drawable: GLXDrawable, mask: ^uint ) ---
    GetProcAddress :: proc "c" (procName: cstring) -> __GLXextFuncPtr ---
    GetProcAddressARB :: proc "c"(procName: cstring) -> __GLXextFuncPtr ---
}


/*
 * Tokens for glXChooseVisual and glXGetConfig:
 */
GLX_USE_GL            ::	1
GLX_BUFFER_SIZE       ::	2
GLX_LEVEL             ::	3
GLX_RGBA		      ::    4
GLX_DOUBLEBUFFER       :: 	5
GLX_STEREO            ::	6
GLX_AUX_BUFFERS       ::	7
GLX_RED_SIZE          ::	8
GLX_GREEN_SIZE        ::	9
GLX_BLUE_SIZE	      ::	10
GLX_ALPHA_SIZE	      ::  	11
GLX_DEPTH_SIZE	      ::  	12
GLX_STENCIL_SIZE      ::	13
GLX_ACCUM_RED_SIZE    ::	14
GLX_ACCUM_GREEN_SIZE  ::	15
GLX_ACCUM_BLUE_SIZE   ::	16
GLX_ACCUM_ALPHA_SIZE  ::	17


/*
 * Error codes returned by glXGetConfig:
 */
GLX_BAD_SCREEN	  ::  	1
GLX_BAD_ATTRIBUTE ::   	2
GLX_NO_EXTENSION  :: 	3
GLX_BAD_VISUAL	  ::  	4
GLX_BAD_CONTEXT	  :: 	5
GLX_BAD_VALUE     :: 	6
GLX_BAD_ENUM	  ::   	7


/*
 * GLX 1.1 and later:
 */
GLX_VENDOR	    :: 	1
GLX_VERSION	    :: 	2
GLX_EXTENSIONS  :: 	3


/*
 * GLX 1.3 and later:
 */
GLX_CONFIG_CAVEAT           :: 0x20
GLX_DONT_CARE		        :: 0xFFFFFFFF
GLX_X_VISUAL_TYPE	        :: 0x22
GLX_TRANSPARENT_TYPE        :: 0x23
GLX_TRANSPARENT_INDEX_VALUE :: 0x24
GLX_TRANSPARENT_RED_VALUE   :: 0x25
GLX_TRANSPARENT_GREEN_VALUE :: 0x26
GLX_TRANSPARENT_BLUE_VALUE  :: 0x27
GLX_TRANSPARENT_ALPHA_VALUE	:: 0x28
GLX_WINDOW_BIT			    :: 0x00000001
GLX_PIXMAP_BIT			    :: 0x00000002
GLX_PBUFFER_BIT			    :: 0x00000004
GLX_AUX_BUFFERS_BIT		    :: 0x00000010
GLX_FRONT_LEFT_BUFFER_BIT	:: 0x00000001
GLX_FRONT_RIGHT_BUFFER_BIT	:: 0x00000002
GLX_BACK_LEFT_BUFFER_BIT	:: 0x00000004
GLX_BACK_RIGHT_BUFFER_BIT	:: 0x00000008
GLX_DEPTH_BUFFER_BIT		:: 0x00000020
GLX_STENCIL_BUFFER_BIT		:: 0x00000040
GLX_ACCUM_BUFFER_BIT		:: 0x00000080
GLX_NONE			        :: 0x8000
GLX_SLOW_CONFIG		        :: 0x8001
GLX_TRUE_COLOR		        :: 0x8002
GLX_DIRECT_COLOR	        :: 0x8003
GLX_PSEUDO_COLOR	        :: 0x8004
GLX_STATIC_COLOR	        :: 0x8005
GLX_GRAY_SCALE		        :: 0x8006
GLX_STATIC_GRAY		        :: 0x8007
GLX_TRANSPARENT_RGB	        :: 0x8008
GLX_TRANSPARENT_INDEX	    :: 0x8009
GLX_VISUAL_ID	            :: 0x800B
GLX_SCREEN		            :: 0x800C
GLX_NON_CONFORMANT_CONFIG	:: 0x800D
GLX_DRAWABLE_TYPE		    :: 0x8010
GLX_RENDER_TYPE			    :: 0x8011
GLX_X_RENDERABLE		    :: 0x8012
GLX_FBCONFIG_ID			    :: 0x8013
GLX_RGBA_TYPE			    :: 0x8014
GLX_COLOR_INDEX_TYPE	    :: 0x8015
GLX_MAX_PBUFFER_WIDTH	    :: 0x8016
GLX_MAX_PBUFFER_HEIGHT	    :: 0x8017
GLX_MAX_PBUFFER_PIXELS	    :: 0x8018
GLX_PRESERVED_CONTENTS	    :: 0x801B
GLX_LARGEST_PBUFFER	        :: 0x801C
GLX_WIDTH		            :: 0x801D
GLX_HEIGHT		            :: 0x801E
GLX_EVENT_MASK	            :: 0x801F
GLX_DAMAGED		            :: 0x8020
GLX_SAVED		            :: 0x8021
GLX_WINDOW		            :: 0x8022
GLX_PBUFFER		            :: 0x8023
GLX_PBUFFER_HEIGHT          :: 0x8040
GLX_PBUFFER_WIDTH           :: 0x8041
GLX_RGBA_BIT		        :: 0x00000001
GLX_COLOR_INDEX_BIT	        :: 0x00000002
GLX_PBUFFER_CLOBBER_MASK	:: 0x08000000


/*
 * GLX 1.4 and later:
 */
GLX_SAMPLE_BUFFERS  ::            0x186a0 /*100000*/
GLX_SAMPLES         ::            0x186a1 /*100001*/


GLXContext :: distinct rawptr


//__GLXcontextRec *GLXContext;
GLXPixmap :: XID
GLXDrawable :: XID
/* GLX 1.3 and later */
//typedef struct __GLXFBConfigRec *GLXFBConfig;
GLXFBConfig :: distinct rawptr
GLXFBConfigID  :: XID
GLXContextID  :: XID
GLXWindow  :: XID
GLXPbuffer  :: XID


/*
** Events.
** __GLX_NUMBER_EVENTS is set to 17 to account for the BufferClobberSGIX
**  event - this helps initialization if the server supports the pbuffer
**  extension and the client doesn't.
*/
GLX_PbufferClobber	  :: 0
GLX_BufferSwapComplete	  :: 1

__GLX_NUMBER_EVENTS ::  17

/* GLX 1.3 function pointer typedefs
typedef GLXFBConfig * (* PFNGLXGETFBCONFIGSPROC) (Display *dpy, int screen, int *nelements);
typedef GLXFBConfig * (* PFNGLXCHOOSEFBCONFIGPROC) (Display *dpy, int screen, const int *attrib_list, int *nelements);
typedef int (* PFNGLXGETFBCONFIGATTRIBPROC) (Display *dpy, GLXFBConfig config, int attribute, int *value);
typedef XVisualInfo * (* PFNGLXGETVISUALFROMFBCONFIGPROC) (Display *dpy, GLXFBConfig config);
typedef GLXWindow (* PFNGLXCREATEWINDOWPROC) (Display *dpy, GLXFBConfig config, Window win, const int *attrib_list);
typedef void (* PFNGLXDESTROYWINDOWPROC) (Display *dpy, GLXWindow win);
typedef GLXPixmap (* PFNGLXCREATEPIXMAPPROC) (Display *dpy, GLXFBConfig config, Pixmap pixmap, const int *attrib_list);
typedef void (* PFNGLXDESTROYPIXMAPPROC) (Display *dpy, GLXPixmap pixmap);
typedef GLXPbuffer (* PFNGLXCREATEPBUFFERPROC) (Display *dpy, GLXFBConfig config, const int *attrib_list);
typedef void (* PFNGLXDESTROYPBUFFERPROC) (Display *dpy, GLXPbuffer pbuf);
typedef void (* PFNGLXQUERYDRAWABLEPROC) (Display *dpy, GLXDrawable draw, int attribute, unsigned int *value);
typedef GLXContext (* PFNGLXCREATENEWCONTEXTPROC) (Display *dpy, GLXFBConfig config, int render_type, GLXContext share_list, Bool direct);
typedef Bool (* PFNGLXMAKECONTEXTCURRENTPROC) (Display *dpy, GLXDrawable draw, GLXDrawable read, GLXContext ctx);
typedef GLXDrawable (* PFNGLXGETCURRENTREADDRAWABLEPROC) (void);
typedef Display * (* PFNGLXGETCURRENTDISPLAYPROC) (void);
typedef int (* PFNGLXQUERYCONTEXTPROC) (Display *dpy, GLXContext ctx, int attribute, int *value);
typedef void (* PFNGLXSELECTEVENTPROC) (Display *dpy, GLXDrawable draw, unsigned long event_mask);
typedef void (* PFNGLXGETSELECTEDEVENTPROC) (Display *dpy, GLXDrawable draw, unsigned long *event_mask);
*/

PFNGLXGETFBCONFIGSPROC :: proc "c" (dpy: ^Display, screen: c.int, nelements: ^c.int) -> ^GLXFBConfig
PFNGLXCHOOSEFBCONFIGPROC :: proc "c" (dpy: ^Display, screen: c.int, attrib_list: [^]c.int, nelements: ^c.int) -> ^GLXFBConfig
PFNGLXGETFBCONFIGATTRIBPROC :: proc "c" (dpy: ^Display, config: GLXFBConfig, attribute: c.int, value: ^c.int) -> c.int
PFNGLXGETVISUALFROMFBCONFIGPROC :: proc "c" (dpy: ^Display, config: GLXFBConfig) -> ^XVisualInfo
PFNGLXCREATEWINDOWPROC :: proc "c" (dpy: ^Display, config: GLXFBConfig, win: Window, attrib_list: [^]c.int) -> GLXWindow
PFNGLXDESTROYWINDOWPROC :: proc "c" (dpy: ^Display, win: GLXWindow)
PFNGLXCREATEPIXMAPPROC :: proc "c" (dpy: ^Display, config: GLXFBConfig, pixmap: Pixmap, attrib_list: [^]c.int) -> GLXPixmap
PFNGLXDESTROYPIXMAPPROC :: proc "c" (dpy: ^Display, pixmap: GLXPixmap)
PFNGLXCREATEPBUFFERPROC :: proc "c" (dpy: ^Display, config: GLXFBConfig, attrib_list: [^]c.int) -> GLXPbuffer
PFNGLXDESTROYPBUFFERPROC :: proc "c" (dpy: ^Display, pbuf: GLXPbuffer)
PFNGLXQUERYDRAWABLEPROC :: proc "c" (dpy: ^Display, draw: GLXDrawable, attribute: c.int, value: ^c.uint)
PFNGLXCREATENEWCONTEXTPROC :: proc "c" (dpy: ^Display, config: GLXFBConfig, render_type: c.int, share_list: GLXContext, direct: bool) -> GLXContext
PFNGLXMAKECONTEXTCURRENTPROC :: proc "c" (dpy: ^Display, draw: GLXDrawable, read: GLXDrawable, ctx: GLXContext) -> bool
PFNGLXGETCURRENTREADDRAWABLEPROC :: proc "c" () -> GLXDrawable
PFNGLXGETCURRENTDISPLAYPROC :: proc "c" () -> ^Display
PFNGLXQUERYCONTEXTPROC :: proc "c" (dpy: ^Display, ctx: GLXContext, attribute: c.int, value: ^c.int) -> c.int
PFNGLXSELECTEVENTPROC :: proc "c" (dpy: ^Display, draw: GLXDrawable, event_mask: c.ulong)

PFNGLXCREATECONTEXTATTRIBSARBPROC :: proc "c" (dpy : ^Display, config : GLXFBConfig, share_context: GLXContext, direct: bool, attrib_list: ^i32) -> GLXContext
//PFNGLXCREATENEWCONTEXTPROC :: proc "c"  (dpy : ^Display, config : GLXFBConfig, render_type: int, share_list : GLXContext, direct: bool) -> GLXContext

/*hhh
 * ARB 2. GLX_ARB_get_proc_address
 */

import "core:c"

__GLXextFuncPtr :: proc "c"()




/* GLX 1.4 and later */
//extern void (*glXGetProcAddress(const GLubyte *procname))( void );


/* GLX 1.4 function pointer typedefs */
//typedef __GLXextFuncPtr (* PFNGLXGETPROCADDRESSPROC) (const GLubyte *procName);
PFNGLXGETPROCADDRESSPROC :: proc "c" (procName: cstring) -> __GLXextFuncPtr


//#ifndef GLX_GLXEXT_LEGACY
//
//#include <GL/glxext.h>
//
//#endif /* GLX_GLXEXT_LEGACY */


/**
 ** The following aren't in glxext.h yet.
 **/


/*
 * ???. GLX_NV_vertex_array_range
 *
#ifndef GLX_NV_vertex_array_range
#define GLX_NV_vertex_array_range

extern void *glXAllocateMemoryNV(GLsizei size, GLfloat readfreq, GLfloat writefreq, GLfloat priority);
extern void glXFreeMemoryNV(GLvoid *pointer);
typedef void * ( * PFNGLXALLOCATEMEMORYNVPROC) (GLsizei size, GLfloat readfreq, GLfloat writefreq, GLfloat priority);
typedef void ( * PFNGLXFREEMEMORYNVPROC) (GLvoid *pointer);

#endif /* GLX_NV_vertex_array_range */


/*
 * ARB ?. GLX_ARB_render_texture
 * XXX This was never finalized!
 */
#ifndef GLX_ARB_render_texture
#define GLX_ARB_render_texture 1

extern Bool glXBindTexImageARB(Display *dpy, GLXPbuffer pbuffer, int buffer);
extern Bool glXReleaseTexImageARB(Display *dpy, GLXPbuffer pbuffer, int buffer);
extern Bool glXDrawableAttribARB(Display *dpy, GLXDrawable draw, const int *attribList);

#endif /* GLX_ARB_render_texture */


/*
 * #?. GLX_MESA_swap_frame_usage
 */
#ifndef GLX_MESA_swap_frame_usage
#define GLX_MESA_swap_frame_usage 1

extern int glXGetFrameUsageMESA(Display *dpy, GLXDrawable drawable, float *usage);
extern int glXBeginFrameTrackingMESA(Display *dpy, GLXDrawable drawable);
extern int glXEndFrameTrackingMESA(Display *dpy, GLXDrawable drawable);
extern int glXQueryFrameTrackingMESA(Display *dpy, GLXDrawable drawable, int64_t *swapCount, int64_t *missedFrames, float *lastMissedUsage);

typedef int (*PFNGLXGETFRAMEUSAGEMESAPROC) (Display *dpy, GLXDrawable drawable, float *usage);
typedef int (*PFNGLXBEGINFRAMETRACKINGMESAPROC)(Display *dpy, GLXDrawable drawable);
typedef int (*PFNGLXENDFRAMETRACKINGMESAPROC)(Display *dpy, GLXDrawable drawable);
typedef int (*PFNGLXQUERYFRAMETRACKINGMESAPROC)(Display *dpy, GLXDrawable drawable, int64_t *swapCount, int64_t *missedFrames, float *lastMissedUsage);

#endif /* GLX_MESA_swap_frame_usage */



/*
 * #?. GLX_MESA_swap_control
 */
#ifndef GLX_MESA_swap_control
#define GLX_MESA_swap_control 1

extern int glXSwapIntervalMESA(unsigned int interval);
extern int glXGetSwapIntervalMESA(void);

typedef int (*PFNGLXSWAPINTERVALMESAPROC)(unsigned int interval);
typedef int (*PFNGLXGETSWAPINTERVALMESAPROC)(void);

#endif /* GLX_MESA_swap_control */

*/

GLX_NV_vertex_array_range :: true

glXAllocateMemoryNV :: proc "c" (size: i64, readfreq: f32, writefreq: f32, priority: f32) -> rawptr
glXFreeMemoryNV :: proc "c" (pointer: rawptr)

PFNGLXALLOCATEMEMORYNVPROC :: proc "c" (size: i32, readfreq, writefreq, priority: f32) -> rawptr
PFNGLXFREEMEMORYNVPROC :: proc "c" (pointer: rawptr)

GLX_ARB_render_texture :: true

glXBindTexImageARB :: proc "c" (dpy: ^Display, pbuffer: GLXPbuffer, buffer: c.int) -> bool
glXReleaseTexImageARB :: proc "c" (dpy: ^Display, pbuffer: GLXPbuffer, buffer: c.int) -> bool
glXDrawableAttribARB :: proc "c" (dpy: ^Display, draw: GLXDrawable, attribList: [^]c.int) -> bool

PFNGLXBINDTEXIMAGEARBPROC :: proc "c" (dpy: ^Display, pbuffer: GLXPbuffer, buffer: c.int) -> bool
PFNGLXRELEASETEXIMAGEARBPROC :: proc "c" (dpy: ^Display, pbuffer: GLXPbuffer, buffer: c.int) -> bool
PFNGLXDRAWABLEATTRIBARBPROC :: proc "c" (dpy: ^Display, draw: GLXDrawable, attribList: [^]c.int) -> bool

GLX_MESA_swap_frame_usage :: true

glXGetFrameUsageMESA :: proc "c" (dpy: ^Display, drawable: GLXDrawable, usage: ^f32) -> c.int
glXBeginFrameTrackingMESA :: proc "c" (dpy: ^Display, drawable: GLXDrawable) -> c.int
glXEndFrameTrackingMESA :: proc "c" (dpy: ^Display, drawable: GLXDrawable) -> c.int
glXQueryFrameTrackingMESA :: proc "c" (dpy: ^Display, drawable: GLXDrawable, swapCount: ^i64, missedFrames: ^i64, lastMissedUsage: ^f32) -> c.int

PFNGLXGETFRAMEUSAGEMESAPROC :: proc "c" (dpy: ^Display, drawable: GLXDrawable, usage: ^f32) -> c.int
PFNGLXBEGINFRAMETRACKINGMESAPROC :: proc "c" (dpy: ^Display, drawable: GLXDrawable) -> c.int
PFNGLXENDFRAMETRACKINGMESAPROC :: proc "c" (dpy: ^Display, drawable: GLXDrawable) -> c.int
PFNGLXQUERYFRAMETRACKINGMESAPROC :: proc "c" (dpy: ^Display, drawable: GLXDrawable, swapCount: ^i64, missedFrames: ^i64, lastMissedUsage: ^f32) -> c.int

GLX_MESA_swap_control :: true

glXSwapIntervalMESA :: proc "c" (interval: c.uint) -> c.int
glXGetSwapIntervalMESA :: proc "c" () -> c.int

PFNGLXSWAPINTERVALMESAPROC :: proc "c" (interval: c.uint) -> c.int
PFNGLXGETSWAPINTERVALMESAPROC :: proc "c" () -> c.int

AllocateMemoryNV: PFNGLXALLOCATEMEMORYNVPROC
FreeMemoryNV: PFNGLXFREEMEMORYNVPROC

BindTexImageARB: PFNGLXBINDTEXIMAGEARBPROC
ReleaseTexImageARB: PFNGLXRELEASETEXIMAGEARBPROC
DrawableAttribARB: PFNGLXDRAWABLEATTRIBARBPROC

GetFrameUsageMESA: PFNGLXGETFRAMEUSAGEMESAPROC
BeginFrameTrackingMESA: PFNGLXBEGINFRAMETRACKINGMESAPROC
EndFrameTrackingMESA: PFNGLXENDFRAMETRACKINGMESAPROC
QueryFrameTrackingMESA: PFNGLXQUERYFRAMETRACKINGMESAPROC

SwapIntervalMESA: PFNGLXSWAPINTERVALMESAPROC
GetSwapIntervalMESA: PFNGLXGETSWAPINTERVALMESAPROC



/*** Should these go here, or in another header? */
/*
** GLX Events
*/
GLXPbufferClobberEvent :: struct {
    event_type : int,		/* GLX_DAMAGED or GLX_SAVED */
    draw_type: int,	/* GLX_WINDOW or GLX_PBUFFER */
    serial: uint,	/* # of last request processed by server */
    send_event: bool,		/* true if this came for SendEvent request */
    display: ^Display,		/* display the event was read from */
    drawable: GLXDrawable, 	/* XID of Drawable */
    buffer_mask: uint,	/* mask indicating which buffers are affected */
    aux_buffer: uint,	/* which aux buffer was affected */
    x, y : int,
    width, height : int,
    count: int,			/* if nonzero, at least this many more */
}

GLXBufferSwapComplete :: struct {
    type: int,
    serial: uint,	/* # of last request processed by server */
    send_event: bool,		/* true if this came from a SendEvent request */
    display: ^Display,		/* Display the event was read from */
    drawable: Drawable,	/* drawable on which event was requested in event mask */
    event_type: int,
    ust : i64,
    msc : i64,
    sbc : i64,
}

GLXEvent ::  struct #raw_union {
    glxpbufferclobber : GLXPbufferClobberEvent,
    glxbufferswapcomplete: GLXBufferSwapComplete,
    pad : [24]c.long,
}


GLX_CONTEXT_DEBUG_BIT_ARB         :: 0x00000001
GLX_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB :: 0x00000002
GLX_CONTEXT_MAJOR_VERSION_ARB     :: 0x2091
GLX_CONTEXT_MINOR_VERSION_ARB     :: 0x2092
GLX_CONTEXT_FLAGS_ARB             :: 0x2094

GLX_CONTEXT_CORE_PROFILE_BIT_ARB  :: 0x00000001
GLX_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB :: 0x00000002
GLX_CONTEXT_PROFILE_MASK_ARB      :: 0x9126