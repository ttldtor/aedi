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
module aermicioi.aedi.test.factory;

import aermicioi.aedi.factory;
import aermicioi.aedi.container;
import aermicioi.aedi.storage;
import aermicioi.aedi.exception;
import aermicioi.aedi.test.fixture;

unittest {
    SingletonContainer container = new SingletonContainer;
    GenericFactory!Employee employee = new GenericFactoryImpl!Employee(container);
    GenericFactory!Company company = new GenericFactoryImpl!Company(container);
    GenericFactory!Job job = new GenericFactoryImpl!Job(container);
    
    container.set("employee", employee);
    container.set("company", company);
    container.set("job", job);
    
    container.instantiate();
}

unittest {
    ObjectStorage!() parameters = new ObjectStorage!();
    parameters.set(name!string, new Wrapper!string("scrapper"));
    parameters.set(name!ubyte, new Wrapper!ubyte(20));
    parameters.set(name!Job, new Job("scrapper", Currency(20000)));
    parameters.link(name!Job, "job");
    parameters.link(name!string, "name");
    parameters.link(name!ubyte, "age");
    GenericFactory!Employee employeeFactory = new GenericFactoryImpl!Employee(parameters);
    
    auto employee = employeeFactory.factory();
    assert(employee !is null);
    
    employeeFactory.construct("scrapper", lref!ubyte, lref!Job);
    employee = employeeFactory.factory();
    
    assert(employee !is null);
    assert(employee.name == "scrapper");
    assert(employee.age == 20);
    assert(employee.job == parameters.get("job"));
    assert(employee.job.name == "scrapper");
    assert(employee.job.payment == 20000);
    
    employeeFactory.autowire();
    employee = employeeFactory.factory();
    
    assert(employee !is null);
    assert(employee.name == "");
    assert(employee.age == 0);
    assert(employee.job is null);
    
    employeeFactory.fact((Locator!() loc, string name, ubyte age) {
        return new Employee(name, age, new Job("scrapped", Currency(0)));
    }, "test", cast(ubyte) 13);
    employeeFactory.callback((Locator!() loc, Employee e, Company comp) {
        e.company = comp;
    },
    new Company(30));
    
    employee = employeeFactory.factory();

    assert(employee !is null);
    assert(employee.name == "test");
    assert(employee.age == 13);
    assert(employee.job != parameters.get("job"));
    assert(employee.job.name == "scrapped");
    assert(employee.job.payment == 0);
    assert(employee.company.id == 30);
}

unittest {
    ObjectStorage!() parameters = new ObjectStorage!();
    parameters.set(name!string, new Wrapper!string("scrapper"));
    parameters.set(name!ubyte, new Wrapper!ubyte(20));
    parameters.set(name!Job, new Job("scrapper", Currency(20000)));
    parameters.set("factory", new FixtureFactory(new Job("salaryman", Currency(2000))));
    parameters.set("structFactory", new Wrapper!StructFixtureFactory(StructFixtureFactory(new Job("salaryman", Currency(2000)))));
    parameters.link(name!Job, "job");
    parameters.link(name!string, "name");
    parameters.link(name!ubyte, "age");
    
    {
        GenericFactory!(Wrapper!Currency) currencyFactory = new GenericFactoryImpl!(Wrapper!Currency)(parameters);
        
        auto currency = currencyFactory.factory;
        assert(currency == Currency());
        currencyFactory.construct(10);
        assert(currencyFactory.factory == Currency(10));
        currencyFactory.set!"amount"(20);
        assert(currencyFactory.factory == Currency(20));
        currencyFactory.set!"amount_"(30);
        assert(currencyFactory.factory == Currency(30));
    }
    
    {
        auto companyFactory = new GenericFactoryImpl!(Company)(parameters);
        companyFactory.factoryMethod!(FixtureFactory, "company");
        assert(companyFactory.factory !is null);
        assert(companyFactory.factory.id == 20);
        
        auto jobFactory = new GenericFactoryImpl!(Job)(parameters);
        jobFactory.factoryMethod!(FixtureFactory, "job")(new FixtureFactory(new Job("billionaire", Currency(2 ^^ 32))));
        assert(jobFactory.factory !is null);
        assert(jobFactory.factory.name == "billionaire");
        assert(jobFactory.factory.payment == Currency(2 ^^ 32));
        
        jobFactory = new GenericFactoryImpl!(Job)(parameters);
        jobFactory.factoryMethod!(FixtureFactory, "job")("factory".lref);
        assert(jobFactory.factory !is null);
        assert(jobFactory.factory.name == "salaryman");
        assert(jobFactory.factory.payment == Currency(2000));
    }
    
    {
        auto companyFactory = new GenericFactoryImpl!(Company)(parameters);
        companyFactory.factoryMethod!(StructFixtureFactory, "company");
        assert(companyFactory.factory !is null);
        assert(companyFactory.factory.id == 20);
        
        auto jobFactory = new GenericFactoryImpl!(Job)(parameters);
        jobFactory.factoryMethod!(StructFixtureFactory, "job")(StructFixtureFactory(new Job("billionaire", Currency(2 ^^ 32))));
        assert(jobFactory.factory !is null);
        assert(jobFactory.factory.name == "billionaire");
        assert(jobFactory.factory.payment == Currency(2 ^^ 32));
        
        jobFactory = new GenericFactoryImpl!(Job)(parameters);
        jobFactory.factoryMethod!(StructFixtureFactory, "job")("structFactory".lref);
        jobFactory.set!"averagePayment"(Currency(150));
        assert(jobFactory.factory !is null);
        assert(jobFactory.factory.name == "salaryman");
        assert(jobFactory.factory.payment == Currency(2000));
        assert(jobFactory.factory.averagePayment == Currency(150));
    }
    
    {
        auto currencyFactory = new GenericFactoryImpl!(Wrapper!(Currency))(parameters);
        currencyFactory.factoryMethod!(StructFixtureFactory, "currency")(StructFixtureFactory(new Job()));
        assert(currencyFactory.factory !is null);
        assert(currencyFactory.factory.amount == 0);
        
        currencyFactory.factoryMethod!(StructFixtureFactory, "basicPayment")(cast(ptrdiff_t) 20);
        assert(currencyFactory.factory !is null);
        assert(currencyFactory.factory.amount == 20);
    }
    
    {
        auto currencyFactory = new GenericFactoryImpl!(Wrapper!(Currency))(parameters);
        currencyFactory.fact(
            delegate Currency(Locator!() loc) {
                return Currency(20);
            }
        );
        assert(currencyFactory.factory !is null);
        assert(currencyFactory.factory.amount == 20);
        
        currencyFactory.callback(
            delegate (Locator!() loc, ref Currency c, int amount) {
                c.amount = amount;
            },
            39
        );
        
        assert(currencyFactory.factory.amount == 39);
    }
}

unittest {
    ObjectStorage!() parameters = new ObjectStorage!();
    parameters.set("name", new Wrapper!string("scrapper"));
    parameters.set("age", new Wrapper!ubyte(20));
    parameters.set(name!Job, new Job("scrapper", Currency(20000)));
    parameters.link(name!Job, "job");
    GenericFactory!Employee employeeFactory = new GenericFactoryImpl!Employee(parameters);
    
    employeeFactory.set!"name"("name".lref);
    employeeFactory.set!"age"("age".lref);
    employeeFactory.set!"job"("job".lref);
    auto employee = employeeFactory.factory();
    
    assert(employee !is null);
    assert(employee.name == "scrapper");
    assert(employee.age == 20);
    assert(employee.job == parameters.get("job"));
    assert(employee.job.name == "scrapper");
    assert(employee.job.payment == 20000);
}

unittest {
    ObjectStorage!() parameters = new ObjectStorage!();
    parameters.set(name!string, new Wrapper!string("scrapper"));
    parameters.set(name!ubyte, new Wrapper!ubyte(20));
    parameters.set(name!Job, new Job("scrapper", Currency(20000)));
    parameters.link(name!Job, "job");
    GenericFactory!Employee employeeFactory = new GenericFactoryImpl!Employee(parameters);
    
    employeeFactory.autowire!"name"();
    employeeFactory.autowire!"age"();
    employeeFactory.autowire!"job"();
    auto employee = employeeFactory.factory();
    
    assert(employee !is null);
    assert(employee.name == "scrapper");
    assert(employee.age == 20);
    assert(employee.job == parameters.get("job"));
    assert(employee.job.name == "scrapper");
    assert(employee.job.payment == 20000);
}