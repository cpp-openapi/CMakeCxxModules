export module hello;

import std.core;

export void greeter(const char *name)
{
    std::cout << "Hello " << name;
}
