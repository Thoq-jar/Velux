#include <print>
#include "dep_demo/lib.h"

int main() {
    std::print("Hello, world!\n");

    std::print("22 + 20 = {}\n", add(22, 20));
}
