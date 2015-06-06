/*
 * Copyright (C) 2012 Intel Corporation. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "config.h"
#include "PlatformUtilities.h"

#include <Ecore.h>
#include <stdio.h>
#include <unistd.h>

namespace TestWebKitAPI {

namespace Util {

void run(bool* done)
{
    while (!*done)
        ecore_main_loop_iterate();
}

void sleep(double seconds)
{
    usleep(seconds * 1000000);
}

WKURLRef createURLForResource(const char* resource, const char* extension)
{
    char url[PATH_MAX];

    snprintf(url, sizeof(url), "file://%s/%s.%s", TEST_WEBKIT2_RESOURCES_DIR, resource, extension);

    return WKURLCreateWithUTF8CString(url);
}

WKStringRef createInjectedBundlePath()
{
    return WKStringCreateWithUTF8CString(TEST_INJECTED_BUNDLE_PATH);
}

WKURLRef URLForNonExistentResource()
{
    return WKURLCreateWithUTF8CString("file:///does-not-exist.html");
}

WKRetainPtr<WKStringRef> MIMETypeForWKURLResponse(WKURLResponseRef wkResponse)
{
    return adoptWK(WKURLResponseCopyMIMEType(wkResponse));
}

} // namespace Util

} // namespace TestWebKitAPI
