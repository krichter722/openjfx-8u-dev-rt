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
#include "glass_window.h"
#include "glass_general.h"
#include "glass_gtkcompat.h"

#include <cstring>
#include <cstdlib>

bool WindowContextBase::hasIME() {
    return xim.enabled;
}

static XKeyPressedEvent convert_event(GdkEventKey *event) {
    XKeyPressedEvent result;
    memset(&result, 0, sizeof (result));

    result.type = (event->type == GDK_KEY_PRESS) ? KeyPress : KeyRelease;
    result.send_event = event->send_event;
    result.display = gdk_x11_display_get_xdisplay(glass_gdk_window_get_display(event->window));
    result.window = result.subwindow = GDK_WINDOW_XID(event->window);
    result.root = GDK_WINDOW_XID(gdk_screen_get_root_window(glass_gdk_window_get_screen(event->window)));
    result.time = event->time;
    result.state = event->state;
    result.keycode = event->hardware_keycode;
    result.same_screen = True;

    return result;
}

bool WindowContextBase::im_filter_keypress(GdkEventKey* event) {
    static size_t buf_len = 12;
    static char *buffer = NULL;

    if (buffer == NULL) {
        buffer = (char*)malloc(buf_len * sizeof (char));
    }

    KeySym keysym;
    Status status;
    XKeyPressedEvent xevent = convert_event(event);
    if (XFilterEvent((XEvent*) & xevent, GDK_WINDOW_XID(gdk_window))) {
        return TRUE;
    }

    int len = Xutf8LookupString(xim.ic, &xevent, buffer, buf_len - 1, &keysym, &status);
    if (status == XBufferOverflow) {
        buf_len = len;
        buffer = (char*)realloc(buffer, buf_len * sizeof (char));
        len = Xutf8LookupString(xim.ic, &xevent, buffer, buf_len - 1,
                &keysym, &status);
    }
    switch (status) {
        case XLookupNone:
            if (event->type == GDK_KEY_RELEASE) {
                process_key(event);
            }
            break;
        case XLookupKeySym:
        case XLookupBoth:
            //process it as a normal key
            process_key(event);
            break;
        case XLookupChars:
            buffer[len] = 0;
            jstring str = mainEnv->NewStringUTF(buffer);
            jsize slen = mainEnv->GetStringLength(str);
            mainEnv->CallVoidMethod(jview,
                    jViewNotifyInputMethod,
                    str,
                    NULL, NULL, NULL,
                    slen,
                    slen,
                    0);

            break;
    }

    return TRUE;
}

bool WindowContextBase::filterIME(GdkEvent * event) {
    if (!hasIME()) {
        return false;
    }

    switch (event->type) {
        case GDK_KEY_PRESS:
        case GDK_KEY_RELEASE:
            return im_filter_keypress(reinterpret_cast<GdkEventKey*> (event));
        default:
            return FALSE;
    }
}

//Note: this function must return int, despite the fact it doesn't conform to XIMProc type.
// This is required in documentation of XIM
static int im_preedit_start(XIM im_xim, XPointer client, XPointer call) {
    return -1; // No restrictions
}

static void im_preedit_done(XIM im_xim, XPointer client, XPointer call) {
}

static void im_preedit_draw(XIM im_xim, XPointer client, XPointer call) {
    XIMPreeditDrawCallbackStruct *data = (XIMPreeditDrawCallbackStruct*) call;
    jstring text = NULL;
    if (data->text != NULL && data->text->string.multi_byte != NULL) {
        if (data->text->encoding_is_wchar) {
            size_t csize = wcstombs(NULL, data->text->string.wide_char, 0);
            char *ctext = new char[csize + 1];
            wcstombs(ctext, data->text->string.wide_char, csize + 1);
            text = mainEnv->NewStringUTF(ctext);
            delete[] ctext;
        } else {
            text = mainEnv->NewStringUTF(data->text->string.multi_byte);
        }
    }

    mainEnv->CallVoidMethod((jobject)client, jViewNotifyInputMethodDraw,
            text, data->chg_first, data->chg_length, data->caret);
}

static void im_preedit_caret(XIM im_xim, XPointer client, XPointer call) {
    XIMPreeditCaretCallbackStruct *data = (XIMPreeditCaretCallbackStruct*) call;
    mainEnv->CallVoidMethod((jobject)client, jViewNotifyInputMethodCaret,
            data->position, data->direction, data->style);
}

static XIMStyle get_best_supported_style(XIM im_xim)
{
    XIMStyles* styles;
    int i;
    XIMStyle result = 0;

    if (XGetIMValues(im_xim, XNQueryInputStyle, &styles, NULL) != NULL) { // NULL means it's OK
        return 0;
    }

    for (i = 0; i < styles->count_styles; ++i) {
        if (styles->supported_styles[i] == (XIMPreeditCallbacks | XIMStatusNothing)) {
            result = styles->supported_styles[i];
            break;
        }
    }

    XFree(styles);

    return result;
}

void WindowContextBase::enableOrResetIME() {
    Display *display = gdk_x11_display_get_xdisplay(glass_gdk_window_get_display(gdk_window));
    if (xim.im == NULL || xim.ic == NULL) {
        xim.im = XOpenIM(display, NULL, NULL, NULL);
        if (xim.im == NULL) {
            return;
        }

        XIMStyle styles = get_best_supported_style(xim.im);
        if (styles == 0) {
            return;
        }

        XIMCallback startCallback = {(XPointer) jview, (XIMProc) im_preedit_start};
        XIMCallback doneCallback = {(XPointer) jview, im_preedit_done};
        XIMCallback drawCallback = {(XPointer) jview, im_preedit_draw};
        XIMCallback caretCallback = {(XPointer) jview, im_preedit_caret};

        XVaNestedList list = XVaCreateNestedList(0,
                XNPreeditStartCallback, &startCallback,
                XNPreeditDoneCallback, &doneCallback,
                XNPreeditDrawCallback, &drawCallback,
                XNPreeditCaretCallback, &caretCallback,
                NULL);

        xim.ic = XCreateIC(xim.im,
                XNInputStyle, styles,
                XNClientWindow, GDK_WINDOW_XID(gdk_window),
                XNPreeditAttributes, list,
                NULL);

        XFree(list);

        if (xim.ic == NULL) {
            return;
        }
    }

    if (xim.enabled) { //called when changed focus to different input
        XmbResetIC(xim.ic);
    }


    XSetICFocus(xim.ic);

    xim.enabled = TRUE;
}

void WindowContextBase::disableIME() {
    if (xim.ic != NULL) {
        XUnsetICFocus(xim.ic);
    }
}