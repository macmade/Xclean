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
    
    @objc private dynamic var loading   = false
    @objc private dynamic var noData    = false
    @objc private dynamic var totalSize = UInt64( 0 )
    
    public override var nibName: NSNib.Name?
    {
        return "MainViewController"
    }
    
    public override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.arrayController.sortDescriptors = [ NSSortDescriptor( key: "name", ascending: true, selector: #selector( NSString.localizedCaseInsensitiveCompare(_:) ) ) ]
    }
    
    public func reload( actionBefore: ( () -> Void )? = nil )
    {
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
    
    @objc private func deleteData( _ data: DerivedData )
    {
        self.delete( url: data.url );
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
            NSWorkspace.shared.selectFile( data.projectPath, inFileViewerRootedAtPath: data.projectPath )
        }
        else if let arranged = self.arrayController.arrangedObjects as? [ DerivedData ]
        {
            if self.tableView.clickedRow >= 0 && arranged.count > self.tableView.clickedRow
            {
                let data = arranged[ self.tableView.clickedRow ]
                
                NSWorkspace.shared.selectFile( data.projectPath, inFileViewerRootedAtPath: data.projectPath )
            }
        }
    }
    
    @IBAction private func openProject( _ sender: Any? )
    {
        if let data = ( sender as? NSMenuItem )?.representedObject as? DerivedData
        {
            NSWorkspace.shared.open( URL( fileURLWithPath: data.projectPath ) )
        }
        else if let arranged = self.arrayController.arrangedObjects as? [ DerivedData ]
        {
            if self.tableView.clickedRow >= 0 && arranged.count > self.tableView.clickedRow
            {
                let data = arranged[ self.tableView.clickedRow ]
                
                NSWorkspace.shared.open( URL( fileURLWithPath: data.projectPath ) )
            }
        }
    }
    
    public func menuWillOpen( _ menu: NSMenu )
    {
        let disable = { menu.items.forEach { $0.isEnabled = false } }
        
        if self.tableView.clickedRow < 0
        {
            disable()
            
            return
        }
        
        guard let arranged = self.arrayController.arrangedObjects as? [ DerivedData ] else
        {
            disable()
            
            return
        }
        
        if self.tableView.clickedRow >= arranged.count
        {
            disable()
            
            return
        }
        
        menu.items.forEach { $0.representedObject = arranged[ self.tableView.clickedRow ] }
    }
}
