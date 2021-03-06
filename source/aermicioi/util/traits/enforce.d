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
module aermicioi.util.traits.enforce;

import aermicioi.util.traits.partial;
import aermicioi.util.traits.traits;
import std.traits;
import std.meta;

template enforceTypeTuple(Original...) {
    
    template enforceTypeTuple(Enforced...) {
        
        static if (Original.length != Enforced.length) {
            enum bool enforceTypeTuple = false;
        } else {
        
            bool enforceTypeTuple() {
                
                bool state = true;
                foreach (index, Type; Original) {

                    static if (!is(Enforced[index] : Type)) {

                        state = false;
                    }
                }
                
                return state;
            }
        }
    }
}

template enforceMethodSignature(InterfaceFunction, Function) {
    alias enforceInterfaceFunctionParameters = enforceTypeTuple!(Parameters!InterfaceFunction);
    enum bool enforceMethodSignature =
        is(ReturnType!Function : ReturnType!InterfaceFunction) &&
        enforceInterfaceFunctionParameters!(Parameters!Function);
}

template enforceMethodSignature(InterfaceFunction, Overloads...)
    if (Overloads.length > 1) {
    
    static if (enforceMethodSignature!(InterfaceFunction, Overloads[0])) {
        
        enum bool enforceMethodSignature = true;
    } else static if (Overloads.length > 1) {
        
        enum bool enforceMethodSignature = enforceMethodSignature!(InterfaceFunction, Overloads[1 .. $]);
    } else {
        
        enum bool enforceMethodSignature = false;
    }
}

template enforceTypeSignature(InterfaceType, Type) {
    
    enum bool enforceTypeSignature =
        Filter!(
            templateNot!(
                templateAnd!(
                    partialPrefixed!(
                        hasMember,
                        Type
                    ),
                    chain!(
                        isSomeFunction,
                        partialPrefixed!(
                            getMember,
                            Type
                        )
                    ),
                    chain!(
                        partialPrefixed!(
                            allSatisfy,
                            chain!(
                                enforceMethodSignature,
                                partial!(
                                    typeOf,
                                    chain!(
                                        partialPrefixed!(
                                            staticMap,
                                            typeOf
                                        ),
                                        partialPrefixed!(
                                            getOverloads,
                                            Type
                                        ),
                                        identifier
                                    )
                                )
                            )
                        ),
                        partialPrefixed!(
                            getOverloads,
                            InterfaceType
                        ),
                    )
                )
            ),
            Filter!(
                failable!(
                    chain!(
                        isSomeFunction,
                        partialPrefixed!(
                            getMember,
                            InterfaceType
                        ),
                    ),
                    false
                ),
                __traits(allMembers, InterfaceType)
            )
        ).length == 0;
}

unittest {
    static interface Interface {
        string method(double);
        void method(int);
        
        void* secondMethod();
        float secondMethod(int, double, float);
    }
    
    import std.stdio;
    
    struct Implementor {
        void method(int);
        string method(double);

        float secondMethod(ubyte, double, double);
        void* secondMethod();
    }
    
    struct WrongImplementor {
        long method(int); // wrong here
        string method(double);

        float secondMethod(int, double, float);
        void* secondMethod();
    }
    
    static assert(enforceTypeSignature!(Interface, Implementor));
    static assert(!enforceTypeSignature!(Interface, WrongImplementor));
}
