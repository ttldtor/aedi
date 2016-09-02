/**
License:
	Boost Software License - Version 1.0 - August 17th, 2003

	Permission is hereby granted, free of charge, to any person or organization
	obtaining a copy of the software and accompanying documentation covered by
	this license (the "Software") to use, reproduce, display, distribute,
	execute, and transmit the Software, and to prepare derivative works of the
	Software, and to permit third-parties to whom the Software is furnished to
	do so, all subject to the following:
	
	The copyright notices in the Software and this entire statement, including
	the above license grant, this restriction and the following disclaimer,
	must be included in all copies of the Software, in whole or in part, and
	all derivative works of the Software, unless such copies or derivative
	works are solely in the form of machine-executable object code generated by
	a source language processor.
	
	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
	SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
	FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
	ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
	DEALINGS IN THE SOFTWARE.

Authors:
	aermicioi
**/
module aermicioi.aedi.test.instantiator.instantiator;

import aermicioi.aedi.test.fixture;
import aermicioi.aedi.instantiator;
import aermicioi.aedi.storage;
import aermicioi.aedi.exception;
import aermicioi.aedi.factory;

class MockFactory(T) : Factory {
    
    protected {
        bool inProcess_;
        Locator!() locator_;
    }
    
    public {
        Object factory() {
            this.inProcess_ = true;
            auto t = new T;
            this.inProcess_ = false;
            
            return t;
        }
        
        @property {
            MockFactory!T locator(Locator!() loc) {
                this.locator_ = loc;
                
                return this;
            }
            
            bool inProcess() {
                return inProcess_;
            }
        }
    }
}

class CircularFactoryMock(T) : MockFactory!T {
    
    public {
        override Object factory() {
            if (this.inProcess_) {
                throw new InProgressException("");
            }
            
            this.inProcess_ = true;
            auto t = new T;
            this.locator_.get("mock");
            this.inProcess_ = false;
            
            return t;
        }
    }
}

unittest {
    import std.range;
    import std.conv;
    SingletonInstantiator instantiator = new SingletonInstantiator;
    
    instantiator.set("mockObject", new MockFactory!Person());
    instantiator.set("mockObject1", new MockFactory!Person());
    instantiator.set("mock", new CircularFactoryMock!Person().locator(instantiator));
    try {
        instantiator.instantiate();
    } catch (CircularReferenceException e) {
        
    }
    
    assert(instantiator.get("mockObject") !is null);
    assert(instantiator.get("mockObject") == instantiator.get("mockObject"));
    assert(instantiator.get("mockObject") != instantiator.get("mockObject1"));
    
    try {
        assert(instantiator.get("unknown") !is null);
    } catch (NotFoundException e) {
        
    }
}

unittest {
    import std.range;
    import std.conv;
    PrototypeInstantiator instantiator = new PrototypeInstantiator;
    
    instantiator.set("mockObject", new MockFactory!Person());
    instantiator.set("mockObject1", new MockFactory!Person());
    instantiator.set("mock", new CircularFactoryMock!Person().locator(instantiator));
    try {
        instantiator.instantiate();
    } catch (CircularReferenceException e) {
        
    }
    
    assert(instantiator.get("mockObject") !is null);
    assert(instantiator.get("mockObject") != instantiator.get("mockObject"));
    assert(instantiator.get("mockObject") != instantiator.get("mockObject1"));
    
    try {
        assert(instantiator.get("unknown") !is null);
    } catch (NotFoundException e) {
        
    }
}