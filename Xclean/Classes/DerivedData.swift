/*******************************************************************************
 * The MIT License (MIT)
 * 
 * Copyright (c) 2020 Jean-David Gadina - www.xs-labs.com
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import Foundation

@objc public class DerivedData: NSObject
{
    @objc public dynamic var url:  URL
    @objc public dynamic var name: String
    @objc public dynamic var size: UInt64
    
    public class func allDerivedData() -> [ DerivedData ]
    {
        if let data = DerivedData( url: URL( fileURLWithPath: "/Users/macmade/Desktop" ) )
        {
            return [ data, data, data ]
        }
        
        return [  ]
    }
    
    public init?( url: URL )
    {
        var isDir = ObjCBool( booleanLiteral: false )
        
        if FileManager.default.fileExists( atPath: url.path, isDirectory: &isDir ) == false || isDir.boolValue == false
        {
            return nil
        }
        
        self.url  = url
        self.name = "foo"
        self.size = 0
    }
}
