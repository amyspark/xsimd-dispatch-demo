#include "main.hpp"

int main()
{
  const auto best_arch = xsimd::available_architectures().best;

#ifdef XSIMD_WITH_SSE2
  if (xsimd::avx2::version() <= best_arch) {
    return test<xsimd::avx2>();
  } else if (xsimd::avx::version() <= best_arch) {
    return test<xsimd::avx>();
  } else if (xsimd::sse4_1::version() <= best_arch) {
    return test<xsimd::sse4_1>();
  } else if (xsimd::ssse3::version() <= best_arch) {
    return test<xsimd::ssse3>();
  } else if (xsimd::sse2::version() <= best_arch) {
    return test<xsimd::sse2>();
  }
#elif XSIMD_WITH_NEON64
  if (xsimd::neon64::version() <= best_arch) {
    return test<xsimd::neon64>();
  }
#elif XSIMD_WITH_NEON
  if (xsimd::neon::version() <= best_arch) {
    return test<xsimd::neon>();
  }
#endif // XSIMD_WITH_SSE2

  return test<xsimd::generic>();
}
