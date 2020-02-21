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
import GitHubUpdates

@NSApplicationMain class ApplicationDelegate: NSObject, NSApplicationDelegate
{
    private var statusItem:             NSStatusItem?
    private var aboutWindowController:  AboutWindowController?
    private var popover:                NSPopover?
    private var mainViewController:     MainViewController?
    private var popoverTranscientEvent: Any?
    private var updateCheckTimer:       Timer?
    private var observations:           [ NSKeyValueObservation ] = []
    
    @objc public dynamic var startAtLogin:                 Bool = false
    @objc public dynamic var automaticallyCheckForUpdates: Bool = false
    
    @IBOutlet private var updater: GitHubUpdater!
    
    func applicationWillFinishLaunching( _ notification: Notification )
    {}
    
    func applicationDidFinishLaunching( _ notification: Notification )
    {
        self.startAtLogin               = NSApp.isLoginItemEnabled()
        self.statusItem                 = NSStatusBar.system.statusItem( withLength: NSStatusItem.squareLength )
        self.statusItem?.button?.target = self
        self.statusItem?.button?.action = #selector( showPopover(_:) )
        self.statusItem?.button?.image  = NSImage( named: "StatusIconTemplate" )
        self.mainViewController         = MainViewController()
        
        let _ = self.mainViewController?.view
        
        let o1 = self.observe( \.startAtLogin )
        {
            [ weak self ] o, c in guard let self = self else { return }
            
            if self.startAtLogin
            {
                NSApp.enableLoginItem()
            }
            else
            {
                NSApp.disableLoginItem()
            }
        }
        
        let o2 = self.observe( \.automaticallyCheckForUpdates )
        {
            [ weak self ] o, c in guard let self = self else { return }
            
            Preferences.shared.autoCheckForUpdates = self.automaticallyCheckForUpdates
            
            if self.automaticallyCheckForUpdates
            {
                self.updateCheckTimer?.invalidate()
                
                self.updateCheckTimer = Timer( timeInterval: 3600, repeats: true )
                {
                    _ in self.updater.checkForUpdatesInBackground()
                }
                
                DispatchQueue.main.asyncAfter( deadline: .now() + .seconds( 5 ) )
                {
                    self.updater.checkForUpdatesInBackground()
                }
            }
            else
            {
                self.updateCheckTimer?.invalidate()
                
                self.updateCheckTimer = nil
            }
        }
        
        self.observations.append( contentsOf: [ o1, o2 ] )
        
        self.automaticallyCheckForUpdates = Preferences.shared.autoCheckForUpdates
        
        #if DEBUG
        
        self.showPopover( nil )
        
        #else
        
        if Preferences.shared.lastStart == nil
        {
            self.showPopover( nil )
        }
        
        #endif
        
        Preferences.shared.lastStart = Date()
    }
    
    func applicationWillTerminate( _ notification: Notification )
    {}
    
    @IBAction func showPopover( _ sender: Any? )
    {
        guard let controller = self.mainViewController else
        {
            return
        }
        
        if Preferences.shared.compactView
        {
            if let event  = NSApp.currentEvent,
               let button = self.statusItem?.button
            {
                self.mainViewController?.reload()
                NSMenu.popUpContextMenu( controller.menuAlternative, with: event, for: button )
            }
        }
        else
        {
            if let popover = self.popover
            {
                if popover.isShown
                {
                    popover.close()
                    
                    return
                }
            }
            
            self.popover                        = NSPopover()
            self.popover?.contentViewController = controller
            self.popover?.behavior              = .applicationDefined
            
            if let button = self.statusItem?.button
            {
                self.mainViewController?.reload()
                self.popover?.show( relativeTo: NSZeroRect, of: button, preferredEdge: NSRectEdge.minY )
            }
            
            self.popoverTranscientEvent = NSEvent.addGlobalMonitorForEvents( matching: .leftMouseUp )
            {
                _ in self.popover?.close()
            }
        }
    }
    
    @IBAction func showAboutWindow( _ sender: Any? )
    {
        if self.popover?.isShown ?? false
        {
            self.popover?.close()
        }
        
        if self.aboutWindowController == nil
        {
            self.aboutWindowController = AboutWindowController()
        }
        
        if self.aboutWindowController?.window?.isVisible == false
        {
            self.aboutWindowController?.window?.center()
        }
        
        NSApp.activate( ignoringOtherApps: true  )
        self.aboutWindowController?.window?.makeKeyAndOrderFront( nil )
    }
    
    @IBAction public func checkForUpdates( _ sender: Any? )
    {
        if self.popover?.isShown ?? false
        {
            self.popover?.close()
        }
        
        NSApp.activate( ignoringOtherApps: true  )
        self.updater.checkForUpdates( sender )
    }
}
