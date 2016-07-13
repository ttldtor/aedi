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
module aermicioi.util.traits;
import std.traits;
import std.typetuple;
import std.algorithm;
import std.array;

public {
    
    enum bool isHashable(T) = isBasicType!(T) || hasMember!(T, "toHash") || is(T == string) || is(T == enum);
    enum bool isPublic(alias T) = __traits(getProtection, T) == "public";
    enum bool isPublic(T, string member) = isPublic!(__traits(getMember, T, member));
    enum bool isMethod(alias T, string member) = isSomeFunction!(__traits(getMember, T, member));
    enum bool evaluateMember(alias pred, T, string member) = pred!(__traits(getMember, T, member));
    enum bool isPropertyGetter(alias func) = (variadicFunctionStyle!func == Variadic.no) && (arity!func == 0) && (functionAttributes!func & FunctionAttribute.property);
    enum bool isPropertySetter(alias func) = (variadicFunctionStyle!func == Variadic.no) && (arity!func == 1) && (functionAttributes!func & FunctionAttribute.property);
    
    enum bool isValue(alias T) = is(typeof(T)) && !is(typeof(T) == void);
    enum bool isValue(T) = false;
    enum bool isType(alias T) = is(T);
    enum bool isProperty(alias T) = 
            (isBasicType!(typeof(T)) || 
                isArray!(typeof(T)) || 
                isAssociativeArray!(typeof(T)) || 
                isAggregateType!(typeof(T)) || 
                is(typeof(T) == enum)
            ) 
            && !isSomeFunction!T
            && !isTemplate!T;
    enum bool isProperty(alias T, string member) = isProperty!(getMember!(T, member));
    enum bool isTypeOrValue(alias T) = isValue!T || isType!T;
    
    enum bool isConstructor(alias T) = isSomeFunction!T && (identifier!T == "__ctor");
    enum bool isDestructor(alias T) = isSomeFunction!T && (identifier!T == "__dtor");
    
    enum bool isConstructor(string T) = T == "__ctor";
    enum bool isDestructor(string T) = T == "__dtor";
    
    template getProperty(alias T, string member) {
        static if (isProperty!(T, member)) {
            alias getProperty = member;
        } else {
            alias getProperty = TypeTuple!();
        }
    }
    
    template identifier(alias T) {
        alias identifier = Identity!(__traits(identifier, T));
    }
    
    template isEmpty(T...) {
        enum bool isEmpty = T.length == 0;
    }
    
    template templateTry(alias pred) {
        template templateTry(alias symbol) {
            static if (__traits(compiles, pred!symbol)) {
             
                alias templateTry = pred!symbol;
            } else {
              
                alias templateTry = symbol;
            }
        }
    }
    
    template templateTryGetOverloads(alias symbol) {
        static if (__traits(compiles, getOverloads!symbol)) {
         
            alias templateTryGetOverloads = getOverloads!symbol;
        } else {
          
            alias templateTryGetOverloads = symbol;
        }
    }
    
    template allMembers(alias Type) {
        alias allMembers = TypeTuple!(__traits(allMembers, Type));
    }
    
    template equals(alias first, alias second) {
        static if (isValue!first && isValue!second && typeCompare!(first, second)) {
            enum bool equals = first == second;
        } else {
            enum bool equals = typeCompare!(first, second);
        }
    }
    
    template isClassOrStructMagicMethods(string member) {
        enum bool isClassOrStructMagicMethods = equals!(member, "this") || equals!(member, "__ctor") || equals!(member, "__dtor");
    }
    
    template staticMapWith(alias pred, alias Type, T...) {
        static if (T.length > 1) {
            alias staticMapWith = TypeTuple!(staticMapWith!(pred, Type, T[0 .. $ / 2]), staticMapWith!(pred, Type, T[$ / 2 .. $]));
        } else static if (T.length == 1) {
            alias staticMapWith = TypeTuple!(pred!(Type, T[0]));
        } else {
            alias staticMapWith = TypeTuple!();
        }
    }
    
    template getMember(alias T, string member) {

        alias getMember = Identity!(__traits(getMember, T, member));
    }

    template getOverloads(alias T, string member) {
        
        alias getOverloads = TypeTuple!(__traits(getOverloads, T, member));
    }
    
    template getOverloadsOrMember(alias T, string member) {
        static if (isSomeFunction!(getMember!(T, member))) {
            alias getOverloadsOrMember = getOverloads!(T, member);
        } else {
            alias getOverloadsOrMember = getMember!(T, member);
        }
    }
    
    template typeCompare(alias first, alias second) {
        static if (isValue!first) {
            static if (isValue!second) {
                
                enum bool typeCompare = is(typeof(first) : typeof(second));
            } else static if (isType!second) {
                
                enum bool typeCompare = is(typeof(first) : second);
            } else {
                
                enum bool typeCompare = false;
            }
        } else static if (isType!first) {
            static if (isValue!second) {
                
                enum bool typeCompare = is(first : typeof(second));
            } else static if (isType!second) {
                
                enum bool typeCompare = is(first : second);
            } else {
                
                enum bool typeCompare = false;
            }
        }
    }
    
    template typeCompare(first, second) {
        enum bool typeCompare = is(first : second);
    }
    
    template typeOf(alias T) {
        static if (isValue!T) {
            alias typeOf = typeof(T);
        } else {
            alias typeOf = T;
        }
    }
    
    template emptyIf(alias pred) {
        template emptyIf(alias T) {
            static if (pred!(T)) {
                alias emptyIf = TypeTuple!();
            } else {
                alias emptyIf = T;
            }
        }
    }
    
    template notEmptyIf(alias pred) {
        template notEmptyIf(alias T) {
            static if (pred!(T)) {
                alias notEmptyIf = T;
            } else {
                alias notEmptyIf = TypeTuple!();
            }
        }
    }
    
    template eq(alias first) {
        enum bool eq(alias second) = (first == second);
    }
    
    template templateStringof(alias T) {
        enum string templateStringof = T.stringof;
    }
    
    template partialPrefixed(alias pred, Args...) {
        template partialPrefixed(Sargs...) {
            alias partialPrefixed = pred!(Args, Sargs);
        }
    }
    
    template partialSuffixed(alias pred, Args...) {
        template partialSuffixed(Sargs...) {
            alias partialSuffixed = pred!(Sargs, Args);
        }
    }
    
    template partial(alias pred) {
        template partial(Args...) {
            alias partial = pred!Args;
        }
    }
    
    template valueSuffixed(alias pred, Args...) {
        template valueSuffixed(T...) {
            auto valueSuffixed(T args) {
                return pred(args, Args);
            }
        }
    }
    
    template valuePrefixed(alias pred, Args...) {
        template valuePrefixed(T...) {
            auto valuePrefixed(T args) {
                return pred(args, Args);
            }
        }
    }
    
    template chain(alias firstPred, alias secondPred, Args...)
        if (isTemplate!secondPred) {
        template chain(Sargs...) {
            alias chain = firstPred!(secondPred!(Args, Sargs));
        }
    }
    
    template chain(alias firstPred, string secondPred, Args) {
        template chain(Sargs...) {
            mixin (secondPred);
            pragma(msg, secondPred);
            
            alias chain = firstPred!(mixed!(Args, Sargs));
        }
    }
    
    template isTemplate(alias T) {
        enum bool isTemplate = __traits(isTemplate, T);
    }
    
    template if_(alias pred, alias trueBranch, alias falseBranch, Args...) {
        template if_ (Sargs...) {
            static if (pred!(Args, Sargs)) {
                alias if_ = trueBranch!(Args, Sargs);
            } else {
                alias if_ = falseBranch!(Args, Sargs);
            }
        }
    }
    
    template execute(alias pred, Args...) {
        static if (isTemplate!pred) {
            alias execute = pred!Args;
        } else static if (isSomeFunction!pred) {
            auto execute = pred(Args);
        }
    }
    
    template failable(alias pred, alias failResponse, Args...) {
        template failable(Sargs...) {
            static if (__traits(compiles, pred!(Args, Sargs))) {
                alias failable = pred!(Args, Sargs);
            } else {
                alias failable = failResponse;
            }
        }
    }
    
    template failed(alias pred, Args...) {
    	enum bool failed = __traits(compiles, pred!Args);
    }
    
    template tee(alias pred, alias debug_ = container!()) {
        template tee(Args...) {
            
            alias tee = pred!Args;
            alias debug__ = debug_!tee;
        }
    }
    
    template container(Args...) {
        template container(Sargs...) {
            alias container = Args;
        }
    }
    
    template pragmaMsg(alias element) {
        pragma(msg, element);
    }
    
    template getAttributes(alias symbol) {
        alias getAttributes = TypeTuple!(__traits(getAttributes, symbol));
    }
    
    template requiredArity(alias symbol) {
        enum bool requiredArity = Filter!(partialPrefixed!(isType, void), ParameterDefaults!symbol);
    }
    
    template isType(Type, alias symbol) {
        enum bool isType = is(symbol == Type);
    }
    
    template isType(Type, Second) {
        enum bool isType = is(symbol == Type);
    }
    
    template isReferenceType(Type) {
        enum bool isReferenceType = is(Type == class) || is(Type == interface);
    }
}