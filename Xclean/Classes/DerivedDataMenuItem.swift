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

public class DerivedDataMenuItem: NSMenuItem
{
    @objc public private( set ) dynamic var data: DerivedData?
    
    private var observations = [ NSKeyValueObservation ]()
    
    public convenience init( data: DerivedData, target: AnyObject, action: Selector )
    {
        self.init( title: data.name, action: nil, keyEquivalent: "" )
        
        self.data              = data
        self.representedObject = data
        self.image             = data.icon.copy() as? NSImage
        self.image?.size       = NSMakeSize( 16, 16 )
        self.target            = target
        self.action            = action
        
        let o1 = data.observe( \.loading ) { [ weak self ] _, _ in self?.updateTitle() }
        let o2 = data.observe( \.size    ) { [ weak self ] _, _ in self?.updateTitle() }
        
        self.observations.append( contentsOf: [ o1, o2 ] )
        
        self.updateTitle()
    }
    
    private func updateTitle()
    {
        guard let data = self.data else
        {
            return
        }
        
        if data.loading || data.size == 0
        {
            self.title = data.name
        }
        else if let humanSize = BytesToString().transformedValue( data.size ) as? String
        {
            self.title = "\(data.name) — \(humanSize)"
        }
    }
}
