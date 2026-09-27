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
import UniformTypeIdentifiers

@objc public class DerivedData: NSObject
{
    // MARK: - Kind
    
    /*
     * The category a cleanable item belongs to.
     * Stored as an Int (rawValue) on the object itself so it stays
     * @objc/KVC-compatible for the existing table/menu bindings.
     */
    @objc public enum Kind: Int
    {
        case derivedData    = 0
        case moduleCache    = 1
        case simulatorCache = 2
        case deviceSupport  = 3
        case spmCache       = 4
        case podsCache      = 5
        case archive        = 6
    }
    
    // MARK: - Icons
    
    /*
     * NSWorkspace.icon(forFileType:) was deprecated in macOS 12 in favor of
     * UTType-based lookups. These two helpers are the only place in this
     * file that touches icons, so every call site below stays warning-free
     * regardless of which kind of identifier it has on hand.
     */
    private static func icon( forFilenameExtension ext: String ) -> NSImage
    {
        let type = UTType( filenameExtension: ext ) ?? .data
        
        return NSWorkspace.shared.icon( for: type )
    }
    
    private static func icon( forUTI uti: String ) -> NSImage
    {
        let type = UTType( uti ) ?? .data
        
        return NSWorkspace.shared.icon( for: type )
    }
    
    // MARK: - Well-known locations
    
    public class var derivedDataURL: URL?
    {
        if let xUD = UserDefaults.init( suiteName: "com.apple.dt.Xcode" ),
           let url = xUD.url( forKey: "IDECustomDerivedDataLocation" )
        {
            return url
        }
        
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
    
    public class var simulatorCachesURL: URL?
    {
        guard let library = NSSearchPathForDirectoriesInDomains( .libraryDirectory, .userDomainMask, true ).first else
        {
            return nil
        }
        
        return URL( fileURLWithPath: library )
            .appendingPathComponent( "Developer" )
            .appendingPathComponent( "CoreSimulator" )
            .appendingPathComponent( "Caches" )
    }
    
    public class var deviceSupportURLs: [ URL ]
    {
        guard let library = NSSearchPathForDirectoriesInDomains( .libraryDirectory, .userDomainMask, true ).first else
        {
            return []
        }
        
        let xcode = URL( fileURLWithPath: library ).appendingPathComponent( "Developer" ).appendingPathComponent( "Xcode" )
        
        return [ "iOS DeviceSupport", "watchOS DeviceSupport", "tvOS DeviceSupport", "visionOS DeviceSupport" ].map
        {
            xcode.appendingPathComponent( $0 )
        }
    }
    
    public class var spmCacheURL: URL?
    {
        guard let caches = NSSearchPathForDirectoriesInDomains( .cachesDirectory, .userDomainMask, true ).first else
        {
            return nil
        }
        
        return URL( fileURLWithPath: caches ).appendingPathComponent( "org.swift.swiftpm" )
    }
    
    public class var podsCacheURL: URL?
    {
        guard let caches = NSSearchPathForDirectoriesInDomains( .cachesDirectory, .userDomainMask, true ).first else
        {
            return nil
        }
        
        return URL( fileURLWithPath: caches ).appendingPathComponent( "CocoaPods" )
    }
    
    public class var archivesURL: URL?
    {
        guard let library = NSSearchPathForDirectoriesInDomains( .libraryDirectory, .userDomainMask, true ).first else
        {
            return nil
        }
        
        return URL( fileURLWithPath: library )
            .appendingPathComponent( "Developer" )
            .appendingPathComponent( "Xcode" )
            .appendingPathComponent( "Archives" )
    }
    
    // MARK: - Properties (all @objc dynamic — bound directly by the table/menu via KVC)
    
    @objc public dynamic var url:         URL
    @objc public dynamic var projectPath: String?
    @objc public dynamic var name:        String
    @objc public dynamic var size:        UInt64
    @objc public dynamic var icon:        NSImage
    @objc public dynamic var loading:     Bool
    @objc public dynamic var zombie:      Bool
    @objc public dynamic var priority:    Int
    @objc public dynamic var kindValue:   Int
    
    public var kind: Kind
    {
        return Kind( rawValue: self.kindValue ) ?? .derivedData
    }
    
    /*
     * Archives are real build artifacts (dSYMs, the exact bits you'd need to
     * resubmit or re-symbolicate a crash) — never a disposable cache. Callers
     * must never include these in any automatic/unattended cleanup path.
     */
    public var isArchive: Bool
    {
        return self.kind == .archive
    }
    
    // MARK: - Discovery
    
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
    
    public class func allSimulatorCaches() -> [ DerivedData ]
    {
        guard let url = simulatorCachesURL else
        {
            return []
        }
        
        guard let item = DerivedData( kind: .simulatorCache, url: url, name: "Simulator Caches", priority: 0, zombie: false, projectPath: nil, iconFileType: "public.folder" ) else
        {
            return []
        }
        
        return [ item ]
    }
    
    public class func allDeviceSupport() -> [ DerivedData ]
    {
        var data = [ DerivedData ]()
        
        for url in deviceSupportURLs
        {
            var isDir = ObjCBool( booleanLiteral: false )
            
            if FileManager.default.fileExists( atPath: url.path, isDirectory: &isDir ) == false || isDir.boolValue == false
            {
                continue
            }
            
            guard let versions = try? FileManager.default.contentsOfDirectory( atPath: url.path ) else
            {
                continue
            }
            
            let platform = url.lastPathComponent.replacingOccurrences( of: " DeviceSupport", with: "" )
            
            for version in versions
            {
                let path = ( url.path as NSString ).appendingPathComponent( version )
                let name = "\(platform) \(version) Device Support"
                
                if let o = DerivedData( kind: .deviceSupport, url: URL( fileURLWithPath: path ), name: name, priority: 0, zombie: false, projectPath: nil, iconFileType: "public.folder" )
                {
                    data.append( o )
                }
            }
        }
        
        return data
    }
    
    public class func allSPMCache() -> [ DerivedData ]
    {
        guard let url = spmCacheURL,
              let item = DerivedData( kind: .spmCache, url: url, name: "Swift Package Manager Cache", priority: 0, zombie: false, projectPath: nil, iconFileType: "public.folder" ) else
        {
            return []
        }
        
        return [ item ]
    }
    
    public class func allPodsCache() -> [ DerivedData ]
    {
        guard let url = podsCacheURL,
              let item = DerivedData( kind: .podsCache, url: url, name: "CocoaPods Cache", priority: 0, zombie: false, projectPath: nil, iconFileType: "public.folder" ) else
        {
            return []
        }
        
        return [ item ]
    }
    
    public class func allArchives() -> [ DerivedData ]
    {
        guard let root = archivesURL else
        {
            return []
        }
        
        var isDir = ObjCBool( booleanLiteral: false )
        
        if FileManager.default.fileExists( atPath: root.path, isDirectory: &isDir ) == false || isDir.boolValue == false
        {
            return []
        }
        
        guard let dateDirs = try? FileManager.default.contentsOfDirectory( atPath: root.path ) else
        {
            return []
        }
        
        var data = [ DerivedData ]()
        
        for dateDir in dateDirs
        {
            let datePath = ( root.path as NSString ).appendingPathComponent( dateDir )
            
            guard let archives = try? FileManager.default.contentsOfDirectory( atPath: datePath ) else
            {
                continue
            }
            
            for archive in archives where archive.hasSuffix( ".xcarchive" )
            {
                let path = ( datePath as NSString ).appendingPathComponent( archive )
                let name = ( archive as NSString ).deletingPathExtension
                
                if let o = DerivedData( kind: .archive, url: URL( fileURLWithPath: path ), name: name, priority: -10, zombie: false, projectPath: nil, iconFileType: "com.apple.xcode.archive" )
                {
                    data.append( o )
                }
            }
        }
        
        return data
    }
    
    /*
     * Everything Xclean knows how to show, in one flat list. Callers that
     * need to exclude Archives from an automatic/unattended action should
     * filter on `isArchive` — never delete an archive without the user
     * explicitly clicking it.
     */
    public class func allCleanableItems() -> [ DerivedData ]
    {
        var items = [ DerivedData ]()
        
        if Preferences.shared.scanDerivedData    { items += allDerivedData()     }
        if Preferences.shared.scanSimulatorCache { items += allSimulatorCaches() }
        if Preferences.shared.scanDeviceSupport  { items += allDeviceSupport()   }
        if Preferences.shared.scanSPMCache       { items += allSPMCache()       }
        if Preferences.shared.scanPodsCache      { items += allPodsCache()      }
        if Preferences.shared.scanArchives       { items += allArchives()       }
        
        return items
    }
    
    /*
     * How long a Simulator/DeviceSupport/SPM/Pods cache has to sit untouched
     * before it's eligible for automatic cleanup. DerivedData/ModuleCache
     * are deliberately NOT covered by this -- they stay zombie-only, as
     * before -- and Archives are never eligible for anything automatic.
     */
    public static let autoCleanStaleAfterDays: Int = 14
    
    public class func staleAutoCleanCandidates() -> [ DerivedData ]
    {
        let cutoff      = Date( timeIntervalSinceNow: -Double( autoCleanStaleAfterDays ) * 86400 )
        var candidates  = [ DerivedData ]()
        
        if Preferences.shared.scanSimulatorCache { candidates += allSimulatorCaches() }
        if Preferences.shared.scanDeviceSupport  { candidates += allDeviceSupport()   }
        if Preferences.shared.scanSPMCache       { candidates += allSPMCache()        }
        if Preferences.shared.scanPodsCache      { candidates += allPodsCache()       }
        
        return candidates.filter
        {
            guard let modified = FileManager.default.lastModifiedInDirectory( at: $0.url ) else
            {
                return false
            }
            
            return modified < cutoff
        }
    }
    
    /*
     * Sums the on-disk size of every known cache/archive root directly
     * (rather than waiting on each item's async size), for a fast total to
     * show in the title bar right after a reload.
     */
    public class func totalSizeOfKnownCaches() -> UInt64
    {
        var urls = [ URL ]()
        
        if Preferences.shared.scanDerivedData,    let u = derivedDataURL     { urls.append( u ) }
        if Preferences.shared.scanSimulatorCache, let u = simulatorCachesURL { urls.append( u ) }
        if Preferences.shared.scanSPMCache,       let u = spmCacheURL        { urls.append( u ) }
        if Preferences.shared.scanPodsCache,      let u = podsCacheURL       { urls.append( u ) }
        if Preferences.shared.scanArchives,       let u = archivesURL        { urls.append( u ) }
        
        if Preferences.shared.scanDeviceSupport
        {
            urls.append( contentsOf: deviceSupportURLs )
        }
        
        return urls.reduce( UInt64( 0 ) ) { $0 + ( FileManager.default.sizeOfDirectory( at: $1 ) ?? 0 ) }
    }
    
    // MARK: - Init
    
    public init?( url: URL )
    {
        var isDir = ObjCBool( booleanLiteral: false )
        
        if FileManager.default.fileExists( atPath: url.path, isDirectory: &isDir ) == false || isDir.boolValue == false
        {
            return nil
        }
        
        if url.lastPathComponent == "ModuleCache.noindex"
        {
            self.url         = url
            self.projectPath = nil
            self.name        = url.lastPathComponent
            self.size        = 0
            self.icon        = DerivedData.icon( forFilenameExtension: "dylib" )
            self.loading     = true
            self.zombie      = false
            self.priority    = 10
            self.kindValue   = Kind.moduleCache.rawValue
        }
        else
        {
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
            
            self.url         = url
            self.projectPath = workspace
            self.name        = FileManager.default.displayName( atPath: workspace )
            self.size        = 0
            self.icon        = DerivedData.icon( forFilenameExtension: ( workspace as NSString ).pathExtension )
            self.loading     = true
            self.zombie      = FileManager.default.fileExists( atPath: workspace ) == false
            self.priority    = 0
            self.kindValue   = Kind.derivedData.rawValue
        }
        
        super.init()
        
        DerivedData.loadSizeAsync( for: self )
    }
    
    /*
     * Designated init for the non-DerivedData cache kinds (Simulator caches,
     * DeviceSupport, SPM cache, Pods cache, Archives): these don't have an
     * Xcode-written info.plist to read a project path from, so they're
     * described directly instead of sniffed from disk layout.
     */
    private convenience init?( kind: Kind, url: URL, name: String, priority: Int, zombie: Bool, projectPath: String?, iconFileType: String )
    {
        var isDir = ObjCBool( booleanLiteral: false )
        
        if FileManager.default.fileExists( atPath: url.path, isDirectory: &isDir ) == false || isDir.boolValue == false
        {
            return nil
        }
        
        self.init( verifiedKind: kind, url: url, name: name, priority: priority, zombie: zombie, projectPath: projectPath, iconFileType: iconFileType )
    }
    
    private init( verifiedKind kind: Kind, url: URL, name: String, priority: Int, zombie: Bool, projectPath: String?, iconFileType: String )
    {
        self.url         = url
        self.projectPath = projectPath
        self.name        = name
        self.size        = 0
        self.icon        = DerivedData.icon( forUTI: iconFileType )
        self.loading     = true
        self.zombie      = zombie
        self.priority    = priority
        self.kindValue   = kind.rawValue
        
        super.init()
        
        DerivedData.loadSizeAsync( for: self )
    }
    
    private class func loadSizeAsync( for item: DerivedData )
    {
        DispatchQueue.global( qos: .default ).async
        {
            let size = FileManager.default.sizeOfDirectory( at: item.url ) ?? 0
            
            DispatchQueue.main.async
            {
                item.size    = size
                item.loading = false
            }
        }
    }
    
    public override func isEqual( _ object: Any? ) -> Bool
    {
        guard let data = object as? DerivedData else
        {
            return false
        }
        
        return self.url == data.url
    }
}
