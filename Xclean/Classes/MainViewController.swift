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
    
    @IBOutlet @objc public dynamic var menuAlternative: NSMenu!
    
    public override var nibName: NSNib.Name?
    {
        return "MainViewController"
    }
    
    public override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.title                           = "Derived Data"
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
            
            let all     = DerivedData.allDerivedData()
            let zombies = all.filter { $0.zombie }
            
            DispatchQueue.main.async
            {
                self.arrayController.remove( contentsOf: zombies )
                self.updateMenu()
            }
            
            for zombie in zombies
            {
                try? FileManager.default.removeItem( at: zombie.url )
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
        self.title   = "Derived Data — Loading..."
        self.loading = true
        
        DispatchQueue.global( qos: .userInitiated ).async
        {
            actionBefore?()
            
            let data = DerivedData.allDerivedData()
            var size = UInt64( 0 )
            
            if let url = DerivedData.derivedDataURL
            {
                size = FileManager.default.sizeOfDirectory( at: url ) ?? 0
            }
            
            DispatchQueue.main.async
            {
                self.arrayController.remove( contentsOf: self.arrayController.content as? [ Any ] ?? [] )
                self.arrayController.add( contentsOf: data )
                
                if let humanSize = BytesToString().transformedValue( size ) as? String
                {
                    self.title = "Derived Data — \(humanSize)"
                }
                else
                {
                    self.title = "Derived Data"
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
            do
            {
                try FileManager.default.removeItem( at: url )
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
        if let data = sender as? DerivedData
        {
            self.delete( url: data.url );
        }
        else if let item = sender                 as? NSMenuItem,
                let data = item.representedObject as? DerivedData
        {
            self.delete( url: data.url );
        }
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
