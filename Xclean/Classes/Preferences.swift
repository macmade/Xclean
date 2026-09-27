/*******************************************************************************
 * The MIT License (MIT)
 * 
 * Copyright (c) 2017 Jean-David Gadina - www.xs-labs.com
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

@objc public class Preferences: NSObject
{
    @objc public dynamic var lastStart:           Date?
    @objc public dynamic var autoCheckForUpdates: Bool   = true
    @objc public dynamic var autoClean:           Bool   = false
    @objc public dynamic var compactView:         Bool   = false
    
    /*
     * Running lifetime stats -- how much space Xclean has ever reclaimed,
     * and when it last did so (manual delete or automatic clean, either
     * one). Persisted through the same generic Mirror-based UserDefaults
     * mechanism as everything else in this class.
     */
    @objc public dynamic var totalBytesReclaimed: UInt64 = 0
    @objc public dynamic var lastCleanedAt:       Date?
    
    /*
     * Which cache categories Xclean actually looks at. All default to true
     * so behavior is unchanged until someone opts a category out from the
     * "Scan For" submenu. DerivedData and ModuleCache share one switch --
     * they live in the same root folder on disk, so splitting them would
     * make the on-disk size total unreliable.
     */
    @objc public dynamic var scanDerivedData:     Bool = true
    @objc public dynamic var scanSimulatorCache:  Bool = true
    @objc public dynamic var scanDeviceSupport:   Bool = true
    @objc public dynamic var scanSPMCache:        Bool = true
    @objc public dynamic var scanPodsCache:       Bool = true
    @objc public dynamic var scanArchives:        Bool = true
    
    @objc public static let shared = Preferences()
    
    override init()
    {
        super.init()
        
        if let path = Bundle.main.path( forResource: "Defaults", ofType: "plist" )
        {
            UserDefaults.standard.register( defaults: NSDictionary( contentsOfFile: path ) as? [ String : Any ] ?? [ : ] )
        }
        
        for c in Mirror( reflecting: self ).children
        {
            guard let key = c.label else
            {
                continue
            }
            
            if let value = UserDefaults.standard.object( forKey: key )
            {
                self.setValue( value, forKey: key )
            }
            
            self.addObserver( self, forKeyPath: key, options: .new, context: nil )
        }
    }
    
    deinit
    {
        for c in Mirror( reflecting: self ).children
        {
            guard let key = c.label else
            {
                continue
            }
            
            self.removeObserver( self, forKeyPath: key )
        }
    }
    
    @objc public override func observeValue( forKeyPath keyPath: String?, of object: Any?, change: [ NSKeyValueChangeKey : Any ]?, context: UnsafeMutableRawPointer? )
    {
        for c in Mirror( reflecting: self ).children
        {
            guard let key = c.label else
            {
                continue
            }
            
            if( key == keyPath )
            {
                UserDefaults.standard.set( change?[ NSKeyValueChangeKey.newKey ], forKey: key )
            }
        }
    }
}
