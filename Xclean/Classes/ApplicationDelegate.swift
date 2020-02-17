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

@NSApplicationMain class ApplicationDelegate: NSObject, NSApplicationDelegate
{
    private var statusItem:            NSStatusItem?
    private var aboutWindowController: AboutWindowController?
    private var popover:               NSPopover?
    private var mainViewController:    MainViewController?
    
    func applicationDidFinishLaunching( _ notification: Notification )
    {
        self.statusItem                     = NSStatusBar.system.statusItem( withLength: NSStatusItem.squareLength )
        self.statusItem?.button?.target     = self
        self.statusItem?.button?.action     = #selector( showPopover(_:) )
        self.statusItem?.button?.image      = NSImage( named: NSImage.applicationIconName )
        self.popover                        = NSPopover()
        self.popover?.contentViewController = MainViewController()
        self.popover?.behavior              = .transient
        self.mainViewController             = self.popover?.contentViewController as? MainViewController
        
        let _ = self.popover?.contentViewController?.view
    }
    
    func applicationWillTerminate( _ notification: Notification )
    {}
    
    @IBAction func showPopover( _ sender: Any? )
    {
        if let button = self.statusItem?.button
        {
            self.mainViewController?.reload()
            self.popover?.show( relativeTo: NSZeroRect, of: button, preferredEdge: NSRectEdge.minY )
        }
    }
    
    @IBAction func showAboutWindow( _ sender: Any? )
    {
        if self.aboutWindowController == nil
        {
            self.aboutWindowController = AboutWindowController()
        }

        if self.aboutWindowController?.window?.isVisible == false
        {
            self.aboutWindowController?.window?.center()
        }
        
        self.aboutWindowController?.window?.makeKeyAndOrderFront( nil )
    }
}
