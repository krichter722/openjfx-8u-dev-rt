/*
 * Copyright (c) 2011, 2013, Oracle and/or its affiliates. All rights reserved.
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
 *
 * This code is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 only, as
 * published by the Free Software Foundation.  Oracle designates this
 * particular file as subject to the "Classpath" exception as provided
 * by Oracle in the LICENSE file that accompanied this code.
 *
 * This code is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * version 2 for more details (a copy is included in the LICENSE file that
 * accompanied this code).
 *
 * You should have received a copy of the GNU General Public License version
 * 2 along with this work; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
 * or visit www.oracle.com if you need additional information or have any
 * questions.
 */

#import "common.h"
#import "com_sun_glass_ui_View.h"
#import "com_sun_glass_ui_mac_MacView.h"
#import "com_sun_glass_ui_View_Capability.h"
#import "com_sun_glass_ui_Clipboard.h"
#import "com_sun_glass_events_ViewEvent.h"

#import "GlassMacros.h"
#import "GlassWindow.h"
#import "GlassView3D.h"

//#define VERBOSE
#ifndef VERBOSE
    #define LOG(MSG, ...)
#else
    #define LOG(MSG, ...) GLASS_LOG(MSG, ## __VA_ARGS__);
#endif

//#define FORCE_NOISE
#ifdef FORCE_NOISE
static inline void *_GenerateNoise(int width, int height)
{
    static int *pixels = NULL;
    pixels = realloc(pixels, width*height*4);
    
    int *src = pixels;
    for (int i=0; i<width*height; i++)
    {
        *src++ = random();
    }
    
    return (void*)pixels;
}
#endif

static inline NSView<GlassView>* getGlassView(JNIEnv *env, jlong jPtr)
{
    if (jPtr != 0L)
    {
        return (NSView<GlassView>*)jlong_to_ptr(jPtr);
    }
    else
    {
        return nil;
    }
}

static inline NSString* getNSString(JNIEnv* env, jstring jstring)
{
    NSString *string = @"";
    if (jstring != NULL)
    {
        const jchar* jstrChars = (*env)->GetStringChars(env, jstring, NULL);
        jsize size = (*env)->GetStringLength(env, jstring);
        if (size > 0)
        {
            string = [[[NSString alloc] initWithCharacters:jstrChars length:(NSUInteger)size] autorelease];
        }
        (*env)->ReleaseStringChars(env, jstring, jstrChars);
    }
    return string;
}

#pragma mark --- Dispatcher

static jlong Do_com_sun_glass_ui_mac_MacView__1create(JNIEnv *env, jobject jView, jobject jCapabilities)
{
    NSView<GlassView> *view = nil;
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    {
        // embed ourselves into GlassHostView, so we can later swap our view between windows (ex. fullscreen mode)
        NSView *hostView = [[GlassHostView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)]; // alloc creates ref count of 1
        [hostView setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
        [hostView setAutoresizesSubviews:YES];
        
        view = [[GlassView3D alloc] initWithFrame:[hostView bounds] withJview:jView withJproperties:jCapabilities];
        [view setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
        
        [hostView addSubview:view];
        (*env)->SetLongField(env, jView, (*env)->GetFieldID(env, jViewClass, "ptr", "J"), ptr_to_jlong(view));
    }
    [pool drain];
    
    GLASS_CHECK_EXCEPTION(env);
    
    return ptr_to_jlong(view);
}

static void Do_com_sun_glass_ui_mac_MacView__1close(JNIEnv *env, jobject jView, jlong jPtr)
{
    NSView<GlassView> *view = getGlassView(env, jPtr);
    NSView * host = [view superview];
    if (host != nil) {
        [view removeFromSuperview];
        [host release];
    }
    [view release];
}

static void Do_com_sun_glass_ui_mac_MacView__1enterFullscreen(JNIEnv *env, jobject jView, jlong jPtr, jboolean jAnimate, jboolean jKeepRatio, jboolean jHideCursor)
{
    NSView<GlassView> *view = getGlassView(env, jPtr);
    [view enterFullscreenWithAnimate:(jAnimate==JNI_TRUE) withKeepRatio:(jKeepRatio==JNI_TRUE) withHideCursor:(jHideCursor==JNI_TRUE)];
}

static void Do_com_sun_glass_ui_mac_MacView__1exitFullscreen(JNIEnv *env, jobject jView, jlong jPtr, jboolean jAnimate)
{
    NSView<GlassView> *view = getGlassView(env, jPtr);
    [view exitFullscreenWithAnimate:(jAnimate==JNI_TRUE)];
}

@interface GlassViewDispatcher : NSObject
{
@public
    jobject         jView;
    jobject         jCapabilities;
    jlong                jPtr;
    jint                jX;
    jint                jY;
    jint                jW;
    jint                jH;
    jboolean         jAnimate;
    jboolean         jKeepRatio;
    jboolean         jHideCursor;
    jlong                jlongReturn;
}
@end

@implementation GlassViewDispatcher

- (void)Do_com_sun_glass_ui_mac_MacView__1create
{
    GET_MAIN_JENV;
    self->jlongReturn = Do_com_sun_glass_ui_mac_MacView__1create(env, self->jView, self->jCapabilities);
}

- (void)Do_com_sun_glass_ui_mac_MacView__1close
{
    GET_MAIN_JENV;
    Do_com_sun_glass_ui_mac_MacView__1close(env, self->jView, self->jPtr);
}

- (void)Do_com_sun_glass_ui_mac_MacView__1enterFullscreen
{
    GET_MAIN_JENV;
    Do_com_sun_glass_ui_mac_MacView__1enterFullscreen(env, self->jView, self->jPtr, self->jAnimate, self->jKeepRatio, self->jHideCursor);
}

- (void)Do_com_sun_glass_ui_mac_MacView__1exitFullscreen
{
    GET_MAIN_JENV;
    Do_com_sun_glass_ui_mac_MacView__1exitFullscreen(env, self->jView, self->jPtr, self->jAnimate);
}

@end

#pragma mark --- JNI

/*
 * Class:     com_sun_glass_ui_mac_MacView
 * Method:    _initIDs
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_sun_glass_ui_mac_MacView__1initIDs
(JNIEnv *env, jclass jClass)
{
    LOG("Java_com_sun_glass_ui_mac_MacView__1initIDs");
    
    if (jViewClass == NULL)
    {
        jViewClass = (*env)->NewGlobalRef(env, jClass);
    }
    
    if (jIntegerClass == NULL)
    {
        jIntegerClass = (*env)->NewGlobalRef(env, (*env)->FindClass(env, "java/lang/Integer"));
    }
    
    if (jMapClass == NULL)
    {
        jMapClass = (*env)->NewGlobalRef(env, (*env)->FindClass(env, "java/util/Map"));
    }
    
    if (jBooleanClass == NULL)
    {
        jBooleanClass = (*env)->NewGlobalRef(env, (*env)->FindClass(env, "java/lang/Boolean"));
    }
    
    if (jViewNotifyEvent == NULL)
    {
        jViewNotifyEvent = (*env)->GetMethodID(env, jViewClass, "notifyView", "(I)V");
    }
    
    if (jViewNotifyRepaint == NULL)
    {
        jViewNotifyRepaint = (*env)->GetMethodID(env, jViewClass, "notifyRepaint", "(IIII)V");
    }
    
    if (jViewNotifyResize == NULL)
    {
        jViewNotifyResize = (*env)->GetMethodID(env, jViewClass, "notifyResize", "(II)V");
    }
    
    if (jViewNotifyKey == NULL)
    {
        jViewNotifyKey = (*env)->GetMethodID(env, jViewClass, "notifyKey", "(II[CI)V");
    }
    
    if (jViewNotifyMenu == NULL)
    {
        jViewNotifyMenu = (*env)->GetMethodID(env, jViewClass, "notifyMenu", "(IIIIZ)V");
    }
    
    if (jViewNotifyMouse == NULL)
    {
        jViewNotifyMouse = (*env)->GetMethodID(env, jViewClass, "notifyMouse", "(IIIIIIIZZ)V");
    }
    
    if (jViewNotifyScroll == NULL)
    {
        jViewNotifyScroll = (*env)->GetMethodID(env, jViewClass, "notifyScroll", "(IIIIDDIIIIIDD)V");
    }
    
    if (jViewNotifyInputMethod == NULL)
    {
        jViewNotifyInputMethod = (*env)->GetMethodID(env, jViewClass, "notifyInputMethod", "(Ljava/lang/String;[I[I[BIII)V");
    }
    
    if (jViewNotifyInputMethodMac == NULL)
    {
        jclass jMacViewClass = (*env)->FindClass(env, "com/sun/glass/ui/mac/MacView");
        jViewNotifyInputMethodMac = (*env)->GetMethodID(env, jMacViewClass, "notifyInputMethodMac", "(Ljava/lang/String;III)V");
    }
    
    if(jViewNotifyInputMethodCandidatePosRequest == NULL)
    {
        jViewNotifyInputMethodCandidatePosRequest = (*env)->GetMethodID(env, jViewClass, "notifyInputMethodCandidatePosRequest", "(I)[D");
    }
    
    if (jViewNotifyDragEnter == NULL)
    {
        jViewNotifyDragEnter = (*env)->GetMethodID(env, jViewClass, "notifyDragEnter", "(IIIII)I");
    }
    
    if (jViewNotifyDragOver == NULL)
    {
        jViewNotifyDragOver = (*env)->GetMethodID(env, jViewClass, "notifyDragOver", "(IIIII)I");
    }
    
    if (jViewNotifyDragLeave == NULL)
    {
        jViewNotifyDragLeave = (*env)->GetMethodID(env, jViewClass, "notifyDragLeave", "()V");
    }
    
    if (jViewNotifyDragDrop == NULL)
    {
        jViewNotifyDragDrop = (*env)->GetMethodID(env, jViewClass, "notifyDragDrop", "(IIIII)I");
    }
    
    if (jViewNotifyDragEnd == NULL)
    {
        jViewNotifyDragEnd = (*env)->GetMethodID(env, jViewClass, "notifyDragEnd", "(I)V");
    }
    
    if (jMapGetMethod == NULL)
    {
        jMapGetMethod = (*env)->GetMethodID(env, jMapClass, "get", "(Ljava/lang/Object;)Ljava/lang/Object;");
    }
    
    if (jBooleanValueMethod == NULL)
    {
        jBooleanValueMethod = (*env)->GetMethodID(env, jBooleanClass, "booleanValue", "()Z");
    }
    
    if (jIntegerInitMethod == NULL)
    {
        jIntegerInitMethod = (*env)->GetMethodID(env, jIntegerClass, "<init>", "(I)V");
    }
    
    if (jIntegerValueMethod == NULL)
    {
        jIntegerValueMethod = (*env)->GetMethodID(env, jIntegerClass, "intValue", "()I");
    }
        
    if (jLongClass == NULL)
    {
        jLongClass = (*env)->NewGlobalRef(env, (*env)->FindClass(env, "java/lang/Long"));
    }
    
    if (jLongValueMethod == NULL)
    {
        jLongValueMethod = (*env)->GetMethodID(env, jLongClass, "longValue", "()J");
    }
}

/*
 * Class:     com_sun_glass_ui_mac_MacView
 * Method:    _getMultiClickTime_impl
 * Signature: ()J
 */
JNIEXPORT jlong JNICALL Java_com_sun_glass_ui_mac_MacView__1getMultiClickTime_1impl
(JNIEnv *env, jclass cls)
{
    LOG("Java_com_sun_glass_ui_mac_MacView__1getMultiClickTime_1impl");
    
    GLASS_ASSERT_MAIN_JAVA_THREAD(env);
    
    // 10.6 API
    return (jlong)([NSEvent doubleClickInterval]*1000.0f);
}

/*
 * Class:     com_sun_glass_ui_mac_MacView
 * Method:    _getMultiClickMaxX_impl
 * Signature: ()I
 */
JNIEXPORT jint JNICALL Java_com_sun_glass_ui_mac_MacView__1getMultiClickMaxX_1impl
(JNIEnv *env, jclass cls)
{
    LOG("Java_com_sun_glass_ui_mac_MacView__1getMultiClickMaxX_1impl");
    
    GLASS_ASSERT_MAIN_JAVA_THREAD(env);
    
    // gznote: there is no way to get this value out of the system
    // Most of the Mac machines use the value 3, so we hardcode this value
    return (jint)3;
}

/*
 * Class:     com_sun_glass_ui_mac_MacView
 * Method:    _getMultiClickMaxY_impl
 * Signature: ()I
 */
JNIEXPORT jint JNICALL Java_com_sun_glass_ui_mac_MacView__1getMultiClickMaxY_1impl
(JNIEnv *env, jclass cls)
{
    LOG("Java_com_sun_glass_ui_mac_MacView__1getMultiClickMaxY_1impl");
    
    GLASS_ASSERT_MAIN_JAVA_THREAD(env);
    
    // gznote: there is no way to get this value out of the system
    // Most of the Mac machines use the value 3, so we hardcode this value
    return (jint)3;
}

/*
 * Class:     com_sun_glass_ui_mac_MacView
 * Method:    _create
 * Signature: (Ljava/util/Map;)J
 */
JNIEXPORT jlong JNICALL Java_com_sun_glass_ui_mac_MacView__1create
(JNIEnv *env, jobject jView, jobject jCapabilities)
{
    LOG("Java_com_sun_glass_ui_mac_MacView__1create");
    
    jlong value = 0L;
    
    GLASS_ASSERT_MAIN_JAVA_THREAD(env);
    GLASS_POOL_ENTER;
    {
        jobject jViewRef = (*env)->NewGlobalRef(env, jView);
        jobject jCapabilitiesRef = NULL;
        if (jCapabilities != NULL)
        {
            jCapabilitiesRef = (*env)->NewGlobalRef(env, jCapabilities);
        }
        {
            if ([NSThread isMainThread] == YES)
            {
                value = Do_com_sun_glass_ui_mac_MacView__1create(env, jViewRef, jCapabilitiesRef);
            }
            else
            {
                GlassViewDispatcher *dispatcher = [[GlassViewDispatcher alloc] autorelease];
                dispatcher->jView = jViewRef;
                dispatcher->jCapabilities = jCapabilitiesRef;
                [dispatcher performSelectorOnMainThread:@selector(Do_com_sun_glass_ui_mac_MacView__1create) withObject:dispatcher waitUntilDone:YES]; // block and wait for the return value
                value = dispatcher->jlongReturn;
            }
        }
        if (jCapabilities != NULL)
        {
            (*env)->DeleteGlobalRef(env, jCapabilitiesRef);
        }
        (*env)->DeleteGlobalRef(env, jViewRef);
    }
    GLASS_POOL_EXIT;
    GLASS_CHECK_EXCEPTION(env);
    
    LOG("   view: %p", value);
    return value;
}

/*
 * Class:     com_sun_glass_ui_mac_MacView
 * Method:    _getNativeLayer
 * Signature: (J)J
 */
JNIEXPORT jlong JNICALL Java_com_sun_glass_ui_mac_MacView__1getNativeLayer
(JNIEnv *env, jobject jView, jlong jPtr)
{
    LOG("Java_com_sun_glass_ui_mac_MacView__1_getNativeLayer");
    LOG("   view: %p", jPtr);
    
    jlong ptr = 0L;
    
    GLASS_ASSERT_MAIN_JAVA_THREAD(env);
    GLASS_POOL_ENTER;
    {
        NSView<GlassView> *view = getGlassView(env, jPtr);
        ptr = ptr_to_jlong([view layer]);
    }
    GLASS_POOL_EXIT;
    GLASS_CHECK_EXCEPTION(env);
    
    return ptr;
}

/*
 * Class:     com_sun_glass_ui_mac_MacView
 * Method:    _getNativeRemoteLayerId
 * Signature: (JLjava/lang/String;)I
 */
JNIEXPORT jint JNICALL Java_com_sun_glass_ui_mac_MacView__1getNativeRemoteLayerId
(JNIEnv *env, jobject jView, jlong jPtr, jstring jServerString)
{
    LOG("Java_com_sun_glass_ui_mac_MacView__1_getNativeLayerId");
    LOG("   layer: %p", jPtr);
    
    jint layerId = 0;
    
    GLASS_ASSERT_MAIN_JAVA_THREAD(env);
    GLASS_POOL_ENTER;
    {
        NSView<GlassView> *view = getGlassView(env, jPtr);
        layerId = (jint)[view getRemoteLayerIdForServer:getNSString(env, jServerString)];
    }
    GLASS_POOL_EXIT;
    GLASS_CHECK_EXCEPTION(env);
    
    LOG("   layerId: %d", layerId);
    return layerId;
}

/*
 * Class:     com_sun_glass_ui_mac_MacView
 * Method:    _hostRemoteLayerId
 * Signature: (JI)V
 */
JNIEXPORT void JNICALL Java_com_sun_glass_ui_mac_MacView__1hostRemoteLayerId
(JNIEnv *env, jobject jView, jlong jPtr, jint jRemoteLayerId)
{
    LOG("Java_com_sun_glass_ui_mac_MacView__1hostRemoteLayerId");
    
    GLASS_ASSERT_MAIN_JAVA_THREAD(env);
    GLASS_POOL_ENTER;
    {
        if (jRemoteLayerId > 0)
        {
            NSView<GlassView> *view = getGlassView(env, jPtr);
            [view hostRemoteLayerId:(uint32_t)jRemoteLayerId];
        }
    }
    GLASS_POOL_EXIT;
    GLASS_CHECK_EXCEPTION(env);
}

/*
 * Class:     com_sun_glass_ui_mac_MacView
 * Method:    _getX
 * Signature: ()I
 */
JNIEXPORT jint JNICALL Java_com_sun_glass_ui_mac_MacView__1getX
(JNIEnv *env, jobject jView, jlong jPtr)
{
    LOG("Java_com_sun_glass_ui_mac_MacView__1getX");
    
    jint x = 0;
    
    GLASS_ASSERT_MAIN_JAVA_THREAD(env);
    GLASS_POOL_ENTER;
    {
        NSView<GlassView> *view = getGlassView(env, jPtr);
        NSWindow *window = [view window];
        if (window != nil)
        {
            NSRect frame = [window frame];
            NSRect contentRect = [window contentRectForFrameRect:frame];
            x = (jint)(contentRect.origin.x - frame.origin.x);
        }
    }
    GLASS_POOL_EXIT;
    GLASS_CHECK_EXCEPTION(env);
    
    return x;
}

/*
 * Class:     com_sun_glass_ui_mac_MacView
 * Method:    _getY
 * Signature: ()I
 */
JNIEXPORT jint JNICALL Java_com_sun_glass_ui_mac_MacView__1getY
(JNIEnv *env, jobject jView, jlong jPtr)
{
    LOG("Java_com_sun_glass_ui_mac_MacView__1getY");
    
    jint y = 0;
    
    GLASS_ASSERT_MAIN_JAVA_THREAD(env);
    GLASS_POOL_ENTER;
    {
        NSView<GlassView> *view = getGlassView(env, jPtr);
        NSWindow * window = [view window];
        if (window != nil)
        {
            NSRect frame = [window frame];
            NSRect contentRect = [window contentRectForFrameRect:frame];
            
            // Assume that the border in the bottom is zero-sized
            y = (jint)(frame.size.height - contentRect.size.height);
        }
    }
    GLASS_POOL_EXIT;
    GLASS_CHECK_EXCEPTION(env);
    
    return y;
}

/*
 * Class:     com_sun_glass_ui_mac_MacView
 * Method:    _setParent
 * Signature: (JJ)V
 */
JNIEXPORT void JNICALL Java_com_sun_glass_ui_mac_MacView__1setParent
(JNIEnv *env, jobject jView, jlong jPtr, jlong parentPtr)
{
    LOG("Java_com_sun_glass_ui_mac_MacView__1setParent");
    LOG("   view: %p", jPtr);
    LOG("   parent: %p", parentPtr);
    
    GLASS_ASSERT_MAIN_JAVA_THREAD(env);
    // TODO: Java_com_sun_glass_ui_mac_MacView__1setParent
}

/*
 * Class:     com_sun_glass_ui_mac_MacView
 * Method:    _close
 * Signature: (J)Z
 */
JNIEXPORT jboolean JNICALL Java_com_sun_glass_ui_mac_MacView__1close
(JNIEnv *env, jobject jView, jlong jPtr)
{
    LOG("Java_com_sun_glass_ui_mac_MacView__1close");

    GLASS_ASSERT_MAIN_JAVA_THREAD(env);
    GLASS_POOL_ENTER;
    {
        if ([NSThread isMainThread] == YES)
        {
            Do_com_sun_glass_ui_mac_MacView__1close(env, jView, jPtr);
        }
        else
        {
            GlassViewDispatcher *dispatcher = [[GlassViewDispatcher alloc] autorelease];
            dispatcher->jView = jView;
            dispatcher->jPtr = jPtr;
            [dispatcher performSelectorOnMainThread:@selector(Do_com_sun_glass_ui_mac_MacView__1close) withObject:dispatcher waitUntilDone:YES];
        }
    }
    GLASS_POOL_EXIT;
    GLASS_CHECK_EXCEPTION(env);

    return JNI_TRUE;
}

/*
 * Class:     com_sun_glass_ui_mac_MacView
 * Method:    _begin
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_sun_glass_ui_mac_MacView__1begin
(JNIEnv *env, jobject jView, jlong jPtr)
{
    LOG("Java_com_sun_glass_ui_mac_MacView__1begin");
    
    GLASS_ASSERT_MAIN_JAVA_THREAD(env);
    NSView<GlassView> *view = getGlassView(env, jPtr);
    GLASS_POOL_PUSH; // it will be popped by "_end"
    {
        [view retain];
//        [view lockFocus];
        [view begin];
    }
}

/*
 * Class:     com_sun_glass_ui_mac_MacView
 * Method:    _end
 * Signature: (Z)V
 */
JNIEXPORT void JNICALL Java_com_sun_glass_ui_mac_MacView__1end
(JNIEnv *env, jobject jView, jlong jPtr)
{
    LOG("Java_com_sun_glass_ui_mac_MacView__1end");
    
    GLASS_ASSERT_MAIN_JAVA_THREAD(env);
    NSView<GlassView> *view = getGlassView(env, jPtr);
    {
        [view end];
//        [view unlockFocus];
        [view release];
    }
    GLASS_POOL_POP; // it was pushed by "_begin"
}

/*
 * Class:     com_sun_glass_ui_mac_MacView
 * Method:    _scheduleRepaint
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_sun_glass_ui_mac_MacView__1scheduleRepaint
(JNIEnv *env, jobject jView, jlong jPtr)
{
    LOG("Java_com_sun_glass_ui_mac_MacView__1scheduleRepaint");
    
    GLASS_ASSERT_MAIN_JAVA_THREAD(env);
    GLASS_POOL_ENTER;
    {
        NSView<GlassView> *view = getGlassView(env, jPtr);
        [view setNeedsDisplay:YES];
    }
    GLASS_POOL_EXIT;
    GLASS_CHECK_EXCEPTION(env);
}

/*
 * Class:     com_sun_glass_ui_mac_MacView
 * Method:    _enterFullscreen
 * Signature: (ZZZ)V
 */
JNIEXPORT jboolean JNICALL Java_com_sun_glass_ui_mac_MacView__1enterFullscreen
(JNIEnv *env, jobject jView, jlong jPtr, jboolean jAnimate, jboolean jKeepRatio, jboolean jHideCursor)
{
    LOG("Java_com_sun_glass_ui_mac_MacView__1enterFullscreen");
    
    GLASS_ASSERT_MAIN_JAVA_THREAD(env);
    GLASS_POOL_ENTER;
    {
        if ([NSThread isMainThread] == YES)
        {
            Do_com_sun_glass_ui_mac_MacView__1enterFullscreen(env, jView, jPtr, jAnimate, jKeepRatio, jHideCursor);
        }
        else
        {
            GlassViewDispatcher *dispatcher = [[GlassViewDispatcher alloc] autorelease];
            dispatcher->jView = jView;
            dispatcher->jPtr = jPtr;
            dispatcher->jAnimate = jAnimate;
            dispatcher->jKeepRatio = jKeepRatio;
            dispatcher->jHideCursor = jHideCursor;
            [dispatcher performSelectorOnMainThread:@selector(Do_com_sun_glass_ui_mac_MacView__1enterFullscreen) withObject:dispatcher waitUntilDone:YES]; // gznote: YES is safe, but NO would be an optimization
        }
    }
    GLASS_POOL_EXIT;
    GLASS_CHECK_EXCEPTION(env);
    
    return JNI_TRUE; // gznote: remove this return value
}

/*
 * Class:     com_sun_glass_ui_mac_MacView
 * Method:    _exitFullscreen
 * Signature: (Z)V
 */
JNIEXPORT void JNICALL Java_com_sun_glass_ui_mac_MacView__1exitFullscreen
(JNIEnv *env, jobject jView, jlong jPtr, jboolean jAnimate)
{
    LOG("Java_com_sun_glass_ui_mac_MacView__1exitFullscreen");
    
    GLASS_ASSERT_MAIN_JAVA_THREAD(env);
    GLASS_POOL_ENTER;
    {
        if ([NSThread isMainThread] == YES)
        {
            Do_com_sun_glass_ui_mac_MacView__1exitFullscreen(env, jView, jPtr, jAnimate);
        }
        else
        {
            GlassViewDispatcher *dispatcher = [[GlassViewDispatcher alloc] autorelease];
            dispatcher->jView = jView;
            dispatcher->jPtr = jPtr;
            dispatcher->jAnimate = jAnimate;
            [dispatcher performSelectorOnMainThread:@selector(Do_com_sun_glass_ui_mac_MacView__1exitFullscreen) withObject:dispatcher waitUntilDone:YES]; // gznote: YES is safe, but NO would be an optimization
        }
    }
    GLASS_POOL_EXIT;
    GLASS_CHECK_EXCEPTION(env);
}

/*
 * Class:     com_sun_glass_ui_mac_MacView
 * Method:    _uploadPixelsDirect
 * Signature: (JLjava/nio/Buffer;II)V
 */
JNIEXPORT void JNICALL Java_com_sun_glass_ui_mac_MacView__1uploadPixelsDirect
(JNIEnv *env, jobject jView, jlong jPtr, jobject jBuffer, jint jWidth, jint jHeight)
{
    LOG("Java_com_sun_glass_ui_mac_MacView__1uploadPixelsDirect");
    
    GLASS_ASSERT_MAIN_JAVA_THREAD(env);
    NSView<GlassView> *view = getGlassView(env, jPtr);
    
#ifndef FORCE_NOISE
    void *pixels = (*env)->GetDirectBufferAddress(env, jBuffer);
#else
    void *pixels = _GenerateNoise(jWidth, jHeight);
#endif
    
    // must be in the middle of begin/end
    if ((jWidth > 0) && (jHeight > 0))
    {
        [view pushPixels:pixels withWidth:(GLuint)jWidth withHeight:(GLuint)jHeight withEnv:env];
    }
}

/*
 * Class:     com_sun_glass_ui_mac_MacView
 * Method:    _uploadPixelsByteArray
 * Signature: (J[BIII)V
 */
JNIEXPORT void JNICALL Java_com_sun_glass_ui_mac_MacView__1uploadPixelsByteArray
(JNIEnv *env, jobject jView, jlong jPtr, jbyteArray jArray, jint jOffset, jint jWidth, jint jHeight)
{
    LOG("Java_com_sun_glass_ui_mac_MacView__1uploadPixelsByteArray");
    
    GLASS_ASSERT_MAIN_JAVA_THREAD(env);
    
    jboolean isCopy = JNI_FALSE;
    u_int8_t *data = (*env)->GetPrimitiveArrayCritical(env, jArray, &isCopy);
    {
        assert((4*jWidth*jHeight + jOffset) == (*env)->GetArrayLength(env, jArray));
        
        NSView<GlassView> *view = getGlassView(env, jPtr);
        
#ifndef FORCE_NOISE
        void *pixels = (data+jOffset);
#else
        void *pixels = _GenerateNoise(jWidth, jHeight);
#endif
        
        // must be in the middle of begin/end
        if ((jWidth > 0) && (jHeight > 0))
        {
            [view pushPixels:pixels withWidth:(GLuint)jWidth withHeight:(GLuint)jHeight withEnv:env];
        }
    }
    (*env)->ReleasePrimitiveArrayCritical(env, jArray, data, JNI_ABORT);
}

/*
 * Class:     com_sun_glass_ui_mac_MacView
 * Method:    _uploadPixelsIntArray
 * Signature: (J[IIII)V
 */
JNIEXPORT void JNICALL Java_com_sun_glass_ui_mac_MacView__1uploadPixelsIntArray
(JNIEnv *env, jobject jView, jlong jPtr, jintArray jArray, jint jOffset, jint jWidth, jint jHeight)
{
    LOG("Java_com_sun_glass_ui_mac_MacView__1uploadPixelsIntArray");
    
    GLASS_ASSERT_MAIN_JAVA_THREAD(env);
    
    jboolean isCopy = JNI_FALSE;
    u_int32_t *data = (*env)->GetPrimitiveArrayCritical(env, jArray, &isCopy);
    {
        assert((jWidth*jHeight + jOffset) == (*env)->GetArrayLength(env, jArray));
        
        NSView<GlassView> *view = getGlassView(env, jPtr);
        
#ifndef FORCE_NOISE
        void *pixels = (data+jOffset);
#else
        void *pixels = _GenerateNoise(jWidth, jHeight);
#endif
        
        // must be in the middle of begin/end
        if ((jWidth > 0) && (jHeight > 0))
        {
            [view pushPixels:pixels withWidth:(GLuint)jWidth withHeight:(GLuint)jHeight withEnv:env];
        }
    }
    (*env)->ReleasePrimitiveArrayCritical(env, jArray, data, JNI_ABORT);
}

/*
 * Input methods callback
 */

/*
 * Class:     com_sun_glass_ui_mac_MacView
 * Method:    _enableInputMethodEvents
 * Signature: (JZ)V
 */
JNIEXPORT void JNICALL Java_com_sun_glass_ui_mac_MacView__1enableInputMethodEvents
(JNIEnv *env, jobject jView, jlong ptr, jboolean enable)
{
    LOG("Java_com_sun_glass_ui_mac_MacView__1enableInputMethodEvents");

    GLASS_ASSERT_MAIN_JAVA_THREAD(env);
    GLASS_POOL_ENTER;
    {
        NSView<GlassView> *view = getGlassView(env, ptr);
        [view setInputMethodEnabled:(enable==JNI_TRUE)];
    }
    GLASS_POOL_EXIT;
    GLASS_CHECK_EXCEPTION(env);
}