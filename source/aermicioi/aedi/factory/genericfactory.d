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
	Alexandru Ermicioi
**/
module aermicioi.aedi.factory.genericfactory;

public import aermicioi.aedi.factory.factory;

import aermicioi.aedi.storage.locator;
import aermicioi.aedi.storage.locator_aware;
import aermicioi.aedi.exception.invalid_cast_exception;
import aermicioi.aedi.exception.in_progress_exception;
import aermicioi.util.traits;

import std.typecons;
import std.traits;
import std.meta;
import std.conv : to;

/**
Interface for objects that can modify an object of type T.

Provides an interface for objects able to modify a setting in an object of type T.
These configurers are used to configure a newly instantiated object usually through setter injenction method, by a GenericFactory implementation.
**/
interface PropertyConfigurer(T) {
    
    public {
        
        /**
        Accepts a reference to an object that is to be configured by the configurer.
        
        Params:
        	object = An object of type T, that will be configured
        **/
        void configure(ref T object);
    }
}

/**
Interface for an object factory.

The objects implementing this interface has the only task of creating the object, by means of a constructor/delegate or any other
form of object creation.
Any object that implements this interface can be used with factories that implement GenericFactory interface to build a new object.
**/
interface InstanceFactory(T) {
    
    public {
        
        /**
        Create a new instance of object of type T.
        **/
        T factory();
    }
}

/**
Provides an interface for factories that construct objects by using building blocks consisting of PropertyConfigurer and 
InstanceFactory objects.

Note:
	The GenericFactory can optionally provide with a (service) locator when it is required by a smaller building blocks like 
	InstanceFactory implementation.
**/
interface GenericFactory(T : Object) : Factory {
    
    public {
        
        /**
        Creates a new object and configures it.
        
        Creates a new object using an InstanceFactory implementation, and afterwards configures it with help of
        PropertyConfigurer implementations.
        
        Throws:
        	InProgressException when the factory is in progress.
        **/
        T factory();
        
        @property {
            
            /**
            Sets the constructor of new object.
            
            Params:
            	factory = a factory of objects of type T.
        	
        	Returns:
    			The GenericFactoryInstance
            **/
            GenericFactory!T setConstructorFactory(InstanceFactory!T factory);
            
            /**
            Get the GenericFactory locator.
            
            Returns:
            	Locator!() the locator that should be used by underlying constructor or property configurer.
            **/
            Locator!() locator();
        }
        
        /**
        Adds an configurer to the GenericFactory.
        
        Params:
        	configurer = a configurer that will be invoked after factory of an object.
        	
    	Returns:
    		The GenericFactoryInstance
        **/
        GenericFactory!T addPropertyFactory(PropertyConfigurer!T configurer);
    }
}

/**
A concrete implementation of GenericFactory interface.

Note:
	This implementation is a (service) locator aware.
**/
class GenericFactoryImpl(T : Object) : GenericFactory!T {
    
    private {
        Locator!() locator_;
        
        InstanceFactory!T factory_;
        
        PropertyConfigurer!T[] configurers;
        bool inProcess_;
    }
    
    public {
        
        this(Locator!() locator) {
            this.locator = locator;
        }
        
        /**
        ditto
        **/
        T factory() {
            if (this.inProcess) {
                throw new InProgressException("Object is already instantiating, type: " ~ name!T);
            }
            
            this.inProcess_ = true;
            
            T instance;
            
            if (this.factory_ !is null) {
                instance = this.factory_.factory;
            } else {
                static if (
                    (hasMember!(T, "__ctor") &&
                    (Filter!(
                            eq!0, 
                            staticMap!(
                                arity,
                                __traits(getOverloads, T, "__ctor")
                            )
                    	).length > 0)) ||
                    !hasMember!(T, "__ctor") 
                ) {
                    instance = new T();
                } else {
                    
                    throw new Exception("Failed to construct object due to no constructor");
                }
            }
            foreach (key, configurer; this.configurers) {
                configurer.configure(instance);
            }
            
            this.inProcess_ = false;
            return instance;
        }
        
        @property {
            
            GenericFactory!T setConstructorFactory(InstanceFactory!T factory) {
                this.factory_ = factory;
                
                return this;
            }
            
            GenericFactoryImpl!T locator(Locator!() locator) {
                this.locator_ = locator;
                return this;
            }
            
            Locator!() locator() {
                return this.locator_;
            }
            
            /**
    		Get the type info of object that is created.
    		
    		Returns:
    			TypeInfo object of created object.
    		**/
    		TypeInfo type() {
    		    return typeid(T);
    		}            
        }
            
        GenericFactory!T addPropertyFactory(PropertyConfigurer!T configurer) {
            
            this.configurers ~= configurer;
            
            return this;
        }
        
		@property bool inProcess() {
		    return this.inProcess_;
		}
    }
}

/**
Implements a setter injection logic for a type T object and for property function method of T object.
**/
class MethodConfigurer(T, string property, Args...) : PropertyConfigurer!T, LocatorAware!()
	if (
	    isObjectMethodCompatible!(T, property, Args)
    ) {
    
    private {
        Locator!() locator_;
        Tuple!Args values;
    }
    
    public {
        
        this(ref Args args) {
            values = args;
        }
        
        /**
        ditto
        **/
        void configure(ref T obj) {
            
            alias ArgTuple = Parameters!(Filter!(partialSuffixed!(isArgumentListCompatible, Args), MemberFunctionsTuple!(T, property))[0]);
            Tuple!ArgTuple args;
            
            foreach (index, ref storage; args) {
                static if (is(typeof(values[index]) : LocatorReference)) {
                    auto st = locator_.locate!(typeof(storage))(values[index].id);
                    
                    if (st is null) {
                        throw new InvalidCastException(
                            "Could not cast object fetched from locator to required class/interface: " ~ 
                            values[index].id.to!string ~ " to " ~ typeid(storage).toString 
                        );
                    }
                    
                    storage = st;
                } else {
                    
                    storage = values[index];
                }
            }
            __traits(getMember, obj, property)(args.expand);
        }
        
		/**
		Sets the locator that will be used by configurer to fetch object referenced in argument list.
		
		Params:
			locator = the (service) locator that will be used to fetch required objects.
		
		Returns:
			The MethodConfigurer!(T, property, Args) instance.
		**/
        @property MethodConfigurer!(T, property, Args) locator(Locator!() locator) {
            this.locator_ = locator;
            
            return this;
        }
    }
}

/**
An implementation of InstanceFactory that uses T's constructor to construct a new object of type T.
**/
class ConstructorBasedFactory(T, Args...) : InstanceFactory!T, LocatorAware!()
	if (
	    isObjectConstructorCompatible!(T, Args)
	) {
    
    private {
        
        Locator!() locator_;
        Tuple!Args values;
    }
    
    public {
        
        this(ref Args args) {
            this.values = tuple(args);
        }
        
        /**
        ditto
        **/
        T factory() {
            
            alias ConstructorArgs = Parameters!(Filter!(partialSuffixed!(isArgumentListCompatible, Args), __traits(getOverloads, T, "__ctor"))[0]);
            
            Tuple!ConstructorArgs args;
            
            foreach (index, ref value; values) {
                
                static if (is(typeof(values[index]) : LocatorReference)) {
                    auto storage = locator_.locate!(typeof(args[index]))(values[index].id);
                    
                    if (storage is null) {
                        throw new InvalidCastException(
                            "Could not cast object fetched from locator to required class/interface: " ~ 
                            values[index].id.to!string ~ " to " ~ typeid(args[index]).toString 
                        );
                    }
                    
                    args[index] = storage;
                } else {
                    
                    args[index] = values[index];
                }
            }
            
            return new T(args.expand);
        }
        
        /**
		Sets the locator that will be used by constructor to fetch object referenced in argument list.
		
		Params:
			locator = the (service) locator that will be used to fetch required objects.
		
		Returns:
			The MethodConfigurer!(T, property, Args) instance.
		**/
        @property ConstructorBasedFactory!(T, Args) locator(Locator!() locator) {
            this.locator_ = locator;
            
            return this;
        }
    }
}

/**
A callback based factory of objects.

It accepts an delegate that is responsible to construct the object, and return it to the GenericFactory for further manipulation.
A list of optional arguments are also possible to pass for delegate.
**/
class CallbackFactory(T, Args...) : InstanceFactory!T {
    
    private {
        T delegate (Locator!(), Args) dg;
        Tuple!Args args;
        Locator!() locator_;
    }
    
    public {
        this(T delegate (Locator!(), Args) dg, ref Args args) {
            this.dg = dg;
            this.args = tuple(args);
        }
        
        T factory() {
            return this.dg(this.locator_, args.expand);
        }
        
        @property CallbackFactory!(T, Args) locator(Locator!() locator) {
            this.locator_ = locator;
            
            return this;
        }
    }
}

GenericFactory!T genericFactory(T)(Locator!() locator) {
    return new GenericFactoryImpl!T(locator);
}

/**
A convenient function that sets to generic factory, a ConstructorBasedFactory as object constructor for type T object.

A convenient function that sets to generic factory, a ConstructorBasedFactory as object constructor for type T object.
Also it takes the locator provided by GenericFactory implementation and passes it to ConstructorBasedFactory for location
of referenced objects.

Params:
	factory = the factory in which to set the new ConstructorBasedFactory object.
	args = the arguments that will be used to construct the new object.
	
Returns:
	GenericFactory!T for which was set the ConstructorBasedFactory.
**/
auto construct(T, Args...)(GenericFactory!T factory, Args args) {
    auto constr = new ConstructorBasedFactory!(T, Args)(args);
    constr.locator = factory.locator;
    factory.setConstructorFactory = constr;
    
    return factory;
}

/**
A convenient function that appends to generic factory, a MethodConfigurer for type T object.

A convenient function that appends to generic factory, a MethodConfigurer as object for type T object.
Also it takes the locator provided by GenericFactory implementation and passes it to MethodConfigurer for location
of referenced objects.

Params:
	factory = the factory in which to set the new ConstructorBasedFactory object.
	args = the arguments that will be used to configure the new object.
	
Returns:
	GenericFactory!T for which was set the MethodConfigurer.
**/
auto set(string property, T, Args...)(GenericFactory!T factory, Args args) 
    if (isObjectMethodCompatible!(T, property, Args)) {
    auto propertySetter = new MethodConfigurer!(T, property, Args)(args);
    propertySetter.locator = factory.locator;
    factory.addPropertyFactory(propertySetter);
    
    return factory;
}

/**
A convenient function that sets to generic factory, a CallbackFactory as object constructor for type T object.

It accepts an delegate that is responsible to construct the object, and return it to the GenericFactory for further manipulation.
A list of optional arguments are also possible to pass to delegate.

Params:
	factory = the factory in which to set the new ConstructorBasedFactory object.
	dg = the delegate that is responsible for creating the object by factory.
	args = the arguments that will be used to construct the new object.
	
Returns:
	GenericFactory!T for which was set the ConstructorBasedFactory.
**/
auto fact(T, Args...)(GenericFactory!T factory, T delegate(Locator!(), Args) dg, Args args) {
    auto constr = new CallbackFactory!(T, Args)(dg, args);
    constr.locator = factory.locator;
    factory.setConstructorFactory(constr);
    return factory;
}

/**
A convenient function that automatically configures an object.

This function if applied to T type, will alias itself to ConstructorBasedFactory with argument list from
first method in overload set of __ctors.
If applied to a method of T type, will alias itself to a MethodBasedFactory with argument list from first method in
overload set of method function

Params:
    factory = GenericFactory where to inject the constructor or method configurer
    
Return 
    factory for further configuration
**/
auto autowire(T)(GenericFactory!T factory) 
    if (getMembersWithProtection!(T, "__ctor", "public").length > 0) {
    return factory.construct!(T)(staticMap!(toLref, Parameters!(getMembersWithProtection!(T, "__ctor", "public")[0])));
}

/**
ditto
**/
auto autowire(string member, T)(GenericFactory!T factory) 
    if (getMembersWithProtection!(T, member, "public").length > 0) {
    return factory.set!(member)(staticMap!(toLref, Parameters!(getMembersWithProtection!(T, member, "public")[0])));
}

/**
An check if the argument list passed to ConstructorBasedFactory or MethodConfigurer is compatible with signature of underlying
method or constructor.

Note:
	For now it checks if the lengths are equal. For future it should also check if types are compatible.
**/
template isArgumentListCompatible(alias func, ArgTuple...) 
	if (isSomeFunction!func) {
    bool isArgumentListCompatible() {
        alias FuncParams = Parameters!func;
        alias Required = Filter!(partialSuffixed!(isValueOfType, void), ParameterDefaults!func);
       
        static if ((ArgTuple.length < Required.length) || (ArgTuple.length > FuncParams.length)) {
          
            return false;
        } else {
          
            foreach (index, Argument; ArgTuple) {
          
                static if (!is(Argument : LocatorReference) && !isImplicitlyConvertible!(Argument, FuncParams[index])) {
          
                    return false;
                } 
            }
            
            return true;
        }
    }
}

template isObjectConstructorCompatible(T, Args...) {
    static assert(hasMember!(T, "__ctor"), identifier!T ~ " doesn't have any constructor to call.");
    static assert(isProtection!(T, "__ctor", "public"), identifier!T ~ "'s constructor is not public.");
    static assert(isSomeFunction!(__traits(getMember, T, "__ctor")), identifier!T ~ "'s constructor is not a function, probably a template.");
    static assert(variadicFunctionStyle!(__traits(getMember, T, "__ctor")) == Variadic.no, identifier!T ~ "'s constructor is a variadic function. Only non-variadic constructors are supported.");
    static assert(Filter!(partialSuffixed!(isArgumentListCompatible, Args), __traits(getOverloads, T, "__ctor")).length == 1, "None, or multiple overloads found for " ~ identifier!T ~ "'s constructor with passed arguments.");
    
    auto isObjectConstructorCompatible() { 
        return 
            hasMember!(T, "__ctor") &&
    	    isProtection!(T, "__ctor", "public") &&
    	    isSomeFunction!(__traits(getMember, T, "__ctor")) &&
    	    (variadicFunctionStyle!(__traits(getMember, T, "__ctor")) == Variadic.no) &&
    	    (Filter!(partialSuffixed!(isArgumentListCompatible, Args), __traits(getOverloads, T, "__ctor")).length == 1);
    }
}

template isObjectMethodCompatible(T, string method, Args...) {
    static assert(hasMember!(T, method), identifier!T ~ "'s method" ~ method ~ " not found.");
    static assert(isProtection!(T, method, "public"), identifier!T ~ "'s method " ~ method ~ " is not public");
    static assert(isSomeFunction!(__traits(getMember, T, method)), identifier!T ~ "'s member " ~ method ~ " is not a function, probably a field, or a function.");
    static assert(variadicFunctionStyle!(__traits(getMember, T, method)) == Variadic.no, identifier!T ~ "'s method " ~ method ~ "is variadic function. Only non-variadic methods are supported.");
    static assert(Filter!(partialSuffixed!(isArgumentListCompatible, Args), MemberFunctionsTuple!(T, method)).length == 1, identifier!T ~ "'s " ~ method ~ " doesn't have overload matching passed arguments, or has several overloads that match.");
    
    auto isObjectMethodCompatible() {
        return 
            hasMember!(T, method) &&
            isProtection!(T, method, "public") &&
            isSomeFunction!(__traits(getMember, T, method)) &&
            (variadicFunctionStyle!(__traits(getMember, T, method)) == Variadic.no) &&
            (Filter!(partialSuffixed!(isArgumentListCompatible, Args), MemberFunctionsTuple!(T, method)).length == 1);
    }
}

	
private template isValueOfType(alias value, Type) {
    enum bool isValueOfType = is(typeof(value) == Type);
}

private template isValueOfType(Value, Type) {
    enum bool isValueOfType = is(Value == Type);
}