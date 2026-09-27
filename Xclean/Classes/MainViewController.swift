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

public class MainViewController: NSViewController, NSMenuDelegate
{
    @IBOutlet private var arrayController: NSArrayController!
    @IBOutlet private var tableView:       NSTableView!
    @IBOutlet private var mainMenu:        NSMenu!
    
    @objc private dynamic var compactView = false
    @objc private dynamic var autoClean   = false
    @objc private dynamic var loading     = false
    @objc private dynamic var noData      = false
    @objc private dynamic var totalSize   = UInt64( 0 )
    
    private var loadedOnce:   Bool                      = false
    private var observations: [ NSKeyValueObservation ] = []
    private var cleanLock:    NSLock                    = NSLock()
    private var timer:        Timer?
    private var lastLoad:     Date?
    private var reclaimedStatsMenuItem: NSMenuItem?
    private var scanScopeMenuItem:     NSMenuItem?
    
    @IBOutlet @objc public dynamic var menuAlternative: NSMenu!
    
    public override var nibName: NSNib.Name?
    {
        return "MainViewController"
    }
    
    public override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.title                           = "Xcode Caches"
        self.arrayController.sortDescriptors = [ NSSortDescriptor( key: "priority", ascending: false ), NSSortDescriptor( key: "name", ascending: true, selector: #selector( NSString.localizedCaseInsensitiveCompare(_:) ) ) ]
        self.autoClean                       = Preferences.shared.autoClean
        self.compactView                     = Preferences.shared.compactView
        self.timer                           = Timer.scheduledTimer( withTimeInterval: 600, repeats: true ) { [ weak self ] _ in self?.cleanZombies() }
        
        let o1 = self.observe( \.autoClean )
        {
            [ weak self ] o, c in guard let self = self else { return }
            
            Preferences.shared.autoClean = self.autoClean
            
            self.cleanZombies()
        }
        
        let o2 = self.observe( \.compactView )
        {
            [ weak self ] o, c in guard let self = self else { return }
            
            Preferences.shared.compactView = self.compactView
        }
        
        let o3 = self.observe( \.loading ) { [ weak self ] o, c in self?.updateMenu() }
        
        self.observations.append( contentsOf: [ o1, o2, o3 ] )
        
        self.installReclaimedStatsMenuItem()
        self.installScanScopeMenu()
    }
    
    /*
     * Adds a disabled, informational item (plus a leading separator) to the
     * end of mainMenu -- right before Quit -- showing lifetime space
     * reclaimed and when Xclean last cleaned anything. Done entirely in
     * code so this never has to touch the XIB.
     */
    private func installReclaimedStatsMenuItem()
    {
        guard self.reclaimedStatsMenuItem == nil else
        {
            return
        }
        
        let statsItem = NSMenuItem( title: "", action: nil, keyEquivalent: "" )
        
        statsItem.isEnabled = false
        
        let insertAt = max( 0, self.mainMenu.items.count - 1 )
        
        self.mainMenu.insertItem( NSMenuItem.separator(), at: insertAt )
        self.mainMenu.insertItem( statsItem, at: insertAt + 1 )
        
        self.reclaimedStatsMenuItem = statsItem
        
        self.updateReclaimedStatsMenuItem()
    }
    
    private func updateReclaimedStatsMenuItem()
    {
        guard let item = self.reclaimedStatsMenuItem else
        {
            return
        }
        
        let total = Preferences.shared.totalBytesReclaimed
        
        guard total > 0, let humanSize = BytesToString().transformedValue( total ) as? String else
        {
            item.title = "Nothing reclaimed yet"
            
            return
        }
        
        if let last = Preferences.shared.lastCleanedAt
        {
            let formatter      = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            
            item.title = "Reclaimed \(humanSize) total (last \(formatter.localizedString( for: last, relativeTo: Date() )))"
        }
        else
        {
            item.title = "Reclaimed \(humanSize) total"
        }
    }
    
    private func recordReclaimed( bytes: UInt64 )
    {
        guard bytes > 0 else
        {
            return
        }
        
        Preferences.shared.totalBytesReclaimed += bytes
        Preferences.shared.lastCleanedAt        = Date()
        
        self.updateReclaimedStatsMenuItem()
    }
    
    /*
     * One case per cache category Xclean knows about. `isEnabled` reads
     * and writes straight through to the matching Preferences.shared.scanXxx
     * flag, so the enum itself holds no state -- it's just a typed,
     * CaseIterable way to walk & label those flags for the "Scan For" menu.
     */
    private enum ScanScope: Int, CaseIterable
    {
        case derivedData    = 0
        case simulatorCache = 1
        case deviceSupport  = 2
        case spmCache       = 3
        case podsCache      = 4
        case archives       = 5
        
        var title: String
        {
            switch self
            {
                case .derivedData:    return "Derived Data & Modules"
                case .simulatorCache: return "Simulator Caches"
                case .deviceSupport:  return "Device Support"
                case .spmCache:       return "Swift Package Manager Cache"
                case .podsCache:      return "CocoaPods Cache"
                case .archives:       return "Archives"
            }
        }
        
        var isEnabled: Bool
        {
            get
            {
                switch self
                {
                    case .derivedData:    return Preferences.shared.scanDerivedData
                    case .simulatorCache: return Preferences.shared.scanSimulatorCache
                    case .deviceSupport:  return Preferences.shared.scanDeviceSupport
                    case .spmCache:       return Preferences.shared.scanSPMCache
                    case .podsCache:      return Preferences.shared.scanPodsCache
                    case .archives:       return Preferences.shared.scanArchives
                }
            }
            set
            {
                switch self
                {
                    case .derivedData:    Preferences.shared.scanDerivedData    = newValue
                    case .simulatorCache: Preferences.shared.scanSimulatorCache = newValue
                    case .deviceSupport:  Preferences.shared.scanDeviceSupport  = newValue
                    case .spmCache:       Preferences.shared.scanSPMCache       = newValue
                    case .podsCache:      Preferences.shared.scanPodsCache      = newValue
                    case .archives:       Preferences.shared.scanArchives       = newValue
                }
            }
        }
    }
    
    /*
     * Adds a "Scan For" submenu (one checkable item per cache category) to
     * mainMenu, just below the reclaimed-stats item and above Quit, so
     * Jamie can turn off categories he doesn't want Xclean to look at or
     * show. Built entirely in code, same as the stats item above -- no
     * XIB changes.
     */
    private func installScanScopeMenu()
    {
        guard self.scanScopeMenuItem == nil else
        {
            return
        }
        
        let scanMenu     = NSMenu( title: "Scan For" )
        let scanMenuItem = NSMenuItem( title: "Scan For", action: nil, keyEquivalent: "" )
        
        scanMenuItem.submenu = scanMenu
        
        for scope in ScanScope.allCases
        {
            let item = NSMenuItem( title: scope.title, action: #selector( self.toggleScanScope(_:) ), keyEquivalent: "" )
            
            item.target = self
            item.tag    = scope.rawValue
            item.state  = scope.isEnabled ? .on : .off
            
            scanMenu.addItem( item )
        }
        
        let insertAt = max( 0, self.mainMenu.items.count - 1 )
        
        self.mainMenu.insertItem( scanMenuItem, at: insertAt )
        
        self.scanScopeMenuItem = scanMenuItem
    }
    
    @objc private func toggleScanScope( _ sender: Any? )
    {
        guard let item = sender as? NSMenuItem, var scope = ScanScope( rawValue: item.tag ) else
        {
            return
        }
        
        scope.isEnabled = scope.isEnabled == false
        
        item.state = scope.isEnabled ? .on : .off
        
        self.reload()
    }
    
    private func cleanZombies()
    {
        if self.autoClean == false
        {
            return
        }
        
        DispatchQueue.global( qos: .background ).async
        {
            if self.cleanLock.try() == false
            {
                return
            }
            
            defer { self.cleanLock.unlock() }
            
            let all      = DerivedData.allDerivedData()
            let zombies  = all.filter { $0.zombie }
            let stale    = DerivedData.staleAutoCleanCandidates()
            let toRemove = zombies + stale
            
            DispatchQueue.main.async
            {
                self.arrayController.remove( contentsOf: toRemove )
                self.updateMenu()
            }
            
            for item in toRemove
            {
                let bytes = FileManager.default.sizeOfDirectory( at: item.url ) ?? 0
                
                try? FileManager.default.removeItem( at: item.url )
                
                if bytes > 0
                {
                    DispatchQueue.main.async { self.recordReclaimed( bytes: bytes ) }
                }
            }
        }
    }
    
    public func reloadIfNeeded()
    {
        if let last = self.lastLoad
        {
            let now = Date( timeIntervalSinceNow: 0 )
            
            if now.timeIntervalSince1970 <= last.timeIntervalSince1970 + 60
            {
                return
            }
        }
        
        self.reload()
    }
    
    public func reload( actionBefore: ( () -> Void )? = nil )
    {
        self.title   = "Xcode Caches — Loading..."
        self.loading = true
        
        DispatchQueue.global( qos: .userInitiated ).async
        {
            actionBefore?()
            
            let data = DerivedData.allCleanableItems()
            let size = DerivedData.totalSizeOfKnownCaches()
            
            DispatchQueue.main.async
            {
                self.arrayController.remove( contentsOf: self.arrayController.content as? [ Any ] ?? [] )
                self.arrayController.add( contentsOf: data )
                
                if let humanSize = BytesToString().transformedValue( size ) as? String
                {
                    self.title = "Xcode Caches — \(humanSize)"
                }
                else
                {
                    self.title = "Xcode Caches"
                }
                
                if( self.loadedOnce == false )
                {
                    self.loadedOnce = true
                    
                    self.cleanZombies()
                }
                
                self.lastLoad  = Date( timeIntervalSinceNow: 0 )
                self.noData    = data.count == 0
                self.totalSize = size
                self.loading   = false
            }
        }
    }
    
    private func delete( url: URL )
    {
        self.reload
        {
            let bytes = FileManager.default.sizeOfDirectory( at: url ) ?? 0
            
            do
            {
                try FileManager.default.removeItem( at: url )
                
                if bytes > 0
                {
                    DispatchQueue.main.async { self.recordReclaimed( bytes: bytes ) }
                }
            }
            catch let e
            {
                let _ = DispatchQueue.main.sync
                {
                    NSAlert( error: e ).runModal()
                }
            }
        }
    }
    
    @objc private func deleteData( _ sender: Any? )
    {
        var target: DerivedData?
        
        if let data = sender as? DerivedData
        {
            target = data
        }
        else if let item = sender                 as? NSMenuItem,
                let data = item.representedObject as? DerivedData
        {
            target = data
        }
        
        guard let data = target else
        {
            return
        }
        
        if data.isArchive
        {
            let alert             = NSAlert()
            alert.messageText     = "Delete Archive?"
            alert.informativeText = "\"\(data.name)\" is an exported build archive, not a cache — it holds the dSYMs and bits you'd need to resubmit this exact build. Deleting it can't be undone."
            alert.alertStyle      = .warning
            
            alert.addButton( withTitle: "Delete Archive" )
            alert.addButton( withTitle: "Cancel" )
            
            if alert.runModal() != .alertFirstButtonReturn
            {
                return
            }
        }
        
        self.delete( url: data.url )
    }
    
    @IBAction private func deleteAll( _ sender: Any? )
    {
        if let url = DerivedData.derivedDataURL
        {
            if FileManager.default.fileExists( atPath: url.path )
            {
                self.delete( url: url )
            }
        }
        else
        {
            NSSound.beep()
        }
    }
    
    @IBAction private func deleteModuleCache( _ sender: Any? )
    {
        if let url = DerivedData.moduleCacheURL
        {
            if FileManager.default.fileExists( atPath: url.path )
            {
                self.delete( url: url )
            }
        }
        else
        {
            NSSound.beep()
        }
    }
    
    @IBAction private func showMenu( _ sender: Any? )
    {
        guard let view = sender as? NSView else
        {
            return
        }
        
        guard let event = NSApp.currentEvent else
        {
            return
        }
        
        NSMenu.popUpContextMenu( self.mainMenu, with: event, for: view )
    }
    
    @IBAction private func showData( _ sender: Any? )
    {
        if let data = ( sender as? NSMenuItem )?.representedObject as? DerivedData
        {
            NSWorkspace.shared.selectFile( data.url.path, inFileViewerRootedAtPath: data.url.path )
        }
        else if let arranged = self.arrayController.arrangedObjects as? [ DerivedData ]
        {
            if self.tableView.clickedRow >= 0 && arranged.count > self.tableView.clickedRow
            {
                let data = arranged[ self.tableView.clickedRow ]
                
                NSWorkspace.shared.selectFile( data.url.path, inFileViewerRootedAtPath: data.url.path )
            }
        }
    }
    
    @IBAction private func showProject( _ sender: Any? )
    {
        if let data = ( sender as? NSMenuItem )?.representedObject as? DerivedData
        {
            if data.zombie == false, let path = data.projectPath
            {
                NSWorkspace.shared.selectFile( data.projectPath, inFileViewerRootedAtPath: path )
            }
        }
        else if let arranged = self.arrayController.arrangedObjects as? [ DerivedData ]
        {
            if self.tableView.clickedRow >= 0 && arranged.count > self.tableView.clickedRow
            {
                let data = arranged[ self.tableView.clickedRow ]
                
                if data.zombie == false, let path = data.projectPath
                {
                    NSWorkspace.shared.selectFile( data.projectPath, inFileViewerRootedAtPath: path )
                }
            }
        }
    }
    
    @IBAction private func openProject( _ sender: Any? )
    {
        if let data = ( sender as? NSMenuItem )?.representedObject as? DerivedData
        {
            if data.zombie == false, let path = data.projectPath
            {
                NSWorkspace.shared.open( URL( fileURLWithPath: path ) )
            }
        }
        else if let arranged = self.arrayController.arrangedObjects as? [ DerivedData ]
        {
            if self.tableView.clickedRow >= 0 && arranged.count > self.tableView.clickedRow
            {
                let data = arranged[ self.tableView.clickedRow ]
                
                if data.zombie == false, let path = data.projectPath
                {
                    NSWorkspace.shared.open( URL( fileURLWithPath: path ) )
                }
            }
        }
    }
    
    @objc private func validateUserInterfaceItem( _ item: NSValidatedUserInterfaceItem ) -> Bool
    {
        guard let menuItem = item as? NSMenuItem else
        {
            return true
        }
        
        if menuItem.menu == self.menuAlternative
        {
            return true
        }
        
        if menuItem.action == #selector( toggleScanScope(_:) )
        {
            return true
        }
        
        if self.tableView.clickedRow < 0
        {
            return false
        }
        
        guard let arranged = self.arrayController.arrangedObjects as? [ DerivedData ] else
        {
            return false
        }
        
        if self.tableView.clickedRow >= arranged.count
        {
            return false
        }
        
        let data = arranged[ self.tableView.clickedRow ]
        
        if data.zombie || data.projectPath == nil
        {
            if menuItem.action == #selector( openProject(_:) )
            {
                return false
            }
            else if menuItem.action == #selector( showProject(_:) )
            {
                return false
            }
        }
        
        return true
    }
    
    private func updateMenu()
    {
        self.menuAlternative.items = self.menuAlternative.items.filter { $0.representedObject == nil }
        
        if self.loading
        {
            return
        }
        
        guard let all = self.arrayController.arrangedObjects as? [ DerivedData ] else
        {
            return
        }
        
        let sorted = all.sorted { o1, o2 in o1.size > o2.size }.filter { $0.name != "ModuleCache.noindex" }
        
        for data in sorted.prefix( 10 ).reversed()
        {
            let item = DerivedDataMenuItem( data: data, target: self, action: #selector( deleteData(_:) ) )
            
            self.menuAlternative.items.insert( item, at: 3 )
        }
    }
    
    public func menuWillOpen( _ menu: NSMenu )
    {
        if menu == self.menuAlternative
        {
            self.reloadIfNeeded()
        }
        else
        {
            self.updateReclaimedStatsMenuItem()
            
            if self.tableView.clickedRow < 0
            {
                return
            }
            
            guard let arranged = self.arrayController.arrangedObjects as? [ DerivedData ] else
            {
                return
            }
            
            if self.tableView.clickedRow >= arranged.count
            {
                return
            }
            
            menu.items.forEach { $0.representedObject = arranged[ self.tableView.clickedRow ] }
        }
    }
}
