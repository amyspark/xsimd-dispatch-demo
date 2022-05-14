#include <iostream>
#include "main.hpp"

template<>
int test<xsimd::current_arch>()
{
    std::cout << typeid(xsimd::current_arch).name() << std::endl;
    return 0;
}
