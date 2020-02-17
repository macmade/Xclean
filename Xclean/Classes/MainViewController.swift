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
    
    @objc private dynamic var loading = false
    
    public override var nibName: NSNib.Name?
    {
        return "MainViewController"
    }
    
    public override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.arrayController.sortDescriptors = [ NSSortDescriptor( key: "name", ascending: true, selector: #selector( NSString.localizedCaseInsensitiveCompare(_:) ) ) ]
        
        self.arrayController.add( contentsOf: DerivedData.allDerivedData() )
    }
    
    private func delete( url: URL )
    {
        self.loading = true
        
        DispatchQueue.global( qos: .userInitiated ).async
        {
            do
            {
                try FileManager.default.removeItem( at: url )
                
                Thread.sleep( forTimeInterval: 0.5 )
            }
            catch let e
            {
                DispatchQueue.main.async
                {
                    NSAlert( error: e ).runModal()
                }
            }
            
            DispatchQueue.main.async
            {
                self.arrayController.remove( contentsOf: self.arrayController.content as? [ Any ] ?? [] )
                self.arrayController.add( contentsOf: DerivedData.allDerivedData() )
                
                self.loading = false
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
            self.delete( url: url )
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
            self.delete( url: url )
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
