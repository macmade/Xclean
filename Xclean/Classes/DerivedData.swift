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

import Cocoa

@objc public class DerivedData: NSObject
{
    public class var derivedDataURL: URL?
    {
        guard let library = NSSearchPathForDirectoriesInDomains( .libraryDirectory, .userDomainMask, true ).first else
        {
            return nil
        }
        
        let developer = ( library   as NSString ).appendingPathComponent( "Developer" )
        let xcode     = ( developer as NSString ).appendingPathComponent( "Xcode" )
        let derived   = ( xcode     as NSString ).appendingPathComponent( "DerivedData" )
        
        return URL( fileURLWithPath: derived )
    }
    
    public class var moduleCacheURL: URL?
    {
        return derivedDataURL?.appendingPathComponent( "ModuleCache.noindex" )
    }
    
    @objc public dynamic var url:         URL
    @objc public dynamic var projectPath: String
    @objc public dynamic var name:        String
    @objc public dynamic var size:        UInt64
    @objc public dynamic var icon:        NSImage
    @objc public dynamic var loading:     Bool
     
    
    public class func allDerivedData() -> [ DerivedData ]
    {
        guard let derived = derivedDataURL else
        {
            return []
        }
        
        var isDir = ObjCBool( booleanLiteral: false )
        
        if FileManager.default.fileExists( atPath: derived.path, isDirectory: &isDir ) == false || isDir.boolValue == false
        {
            return []
        }
        
        guard let dirs = try? FileManager.default.contentsOfDirectory( atPath: derived.path ) else
        {
            return []
        }
        
        var data = [ DerivedData ]()
        
        for dir in dirs
        {
            let path = ( derived.path as NSString ).appendingPathComponent( dir )
            
            if let o = DerivedData( url: URL( fileURLWithPath: path ) )
            {
                data.append( o )
            }
        }
        
        return data
    }
    
    public init?( url: URL )
    {
        var isDir = ObjCBool( booleanLiteral: false )
        
        if FileManager.default.fileExists( atPath: url.path, isDirectory: &isDir ) == false || isDir.boolValue == false
        {
            return nil
        }
        
        let plist = ( url.path as NSString ).appendingPathComponent( "info.plist" )
        
        guard let data = try? Data( contentsOf: URL( fileURLWithPath: plist ) ) else
        {
            return nil
        }
        
        guard let info = try? PropertyListSerialization.propertyList( from: data, options: [], format: nil ) as? [ String : Any ] else
        {
            return nil
        }
        
        guard let workspace = info[ "WorkspacePath" ] as? String else
        {
            return nil
        }
        
        if FileManager.default.fileExists( atPath: workspace ) == false
        {
            return nil
        }
        
        self.url         = url
        self.projectPath = workspace
        self.name        = FileManager.default.displayName( atPath: workspace )
        self.size        = 0
        self.icon        = NSWorkspace.shared.icon( forFile: workspace )
        self.loading     = true
        
        super.init()
        
        DispatchQueue.global( qos: .default ).async
        {
            let size = DerivedData.getDirectorySize( url: url ) ?? 0
            
            DispatchQueue.main.async
            {
                self.size    = size
                self.loading = false
            }
        }
    }
    
    private class func getDirectorySize( url: URL ) -> UInt64?
    {
        var isDir = ObjCBool( booleanLiteral: false )
        
        if FileManager.default.fileExists( atPath: url.path, isDirectory: &isDir ) == false || isDir.boolValue == false
        {
            return nil
        }
        
        guard let enumerator = FileManager.default.enumerator( at: url, includingPropertiesForKeys: [ .fileSizeKey ] ) else
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
            
            if FileManager.default.fileExists( atPath: sub.path, isDirectory: &isDir ) == false
            {
                return nil
            }
            
            if isDir.boolValue
            {
                size += DerivedData.getDirectorySize( url: sub ) ?? 0
            }
            else
            {
                if let res = try? sub.resourceValues( forKeys: [ .fileSizeKey ] )
                {
                    size += UInt64( res.fileSize ?? 0 )
                }
            }
        }
        
        return size
    }
}
