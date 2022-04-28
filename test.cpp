#include <iostream>
#include <xsimd/types/xsimd_generic_arch.hpp>
#include "main.hpp"
#include "xsimd_extensions/config/xsimd_arch.hpp"



template<>
int test<xsimd::current_arch>()
{
    std::cout << typeid(xsimd::current_arch).name() << std::endl;
    return 0;
}
