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

public extension FileManager
{
    func sizeOfDirectory( at url: URL ) -> UInt64?
    {
        var isDir = ObjCBool( booleanLiteral: false )
        
        if self.fileExists( atPath: url.path, isDirectory: &isDir ) == false || isDir.boolValue == false
        {
            return nil
        }
        
        guard let enumerator = self.enumerator( at: url, includingPropertiesForKeys: [ .fileSizeKey ] ) else
        {
            return nil
        }
        
        var size: UInt64 = 0
        
        for ( _, object ) in enumerator.enumerated()
        {
            guard let sub = object as? URL else
            {
                continue
            }
            
            if let res = try? sub.resourceValues( forKeys: [ .fileSizeKey ] )
            {
                size += UInt64( res.fileSize ?? 0 )
            }
        }
        
        return size
    }
    
    /*
     * The most recent modification date of any file inside `url`, recursing
     * into subdirectories -- used to decide whether a cache root has been
     * "touched" recently enough to leave alone. A directory's own mtime only
     * updates when its direct children change, which misses activity nested
     * deeper inside (e.g. a Swift package cache), so this scans the same way
     * sizeOfDirectory(at:) does rather than trusting the root's own mtime.
     */
    func lastModifiedInDirectory( at url: URL ) -> Date?
    {
        var isDir = ObjCBool( booleanLiteral: false )
        
        if self.fileExists( atPath: url.path, isDirectory: &isDir ) == false || isDir.boolValue == false
        {
            return nil
        }
        
        guard let enumerator = self.enumerator( at: url, includingPropertiesForKeys: [ .contentModificationDateKey ] ) else
        {
            return nil
        }
        
        var latest: Date?
        
        for ( _, object ) in enumerator.enumerated()
        {
            guard let sub = object as? URL else
            {
                continue
            }
            
            if let res  = try? sub.resourceValues( forKeys: [ .contentModificationDateKey ] ),
               let date = res.contentModificationDate
            {
                if latest == nil || date > latest!
                {
                    latest = date
                }
            }
        }
        
        return latest ?? ( try? url.resourceValues( forKeys: [ .contentModificationDateKey ] ) )?.contentModificationDate
    }
}
