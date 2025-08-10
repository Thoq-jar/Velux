![Velux](.img/velux-logo.png)

# Velux

A high-performance, scalable build system for C(++)

## Usage:

Create a Velux.json file:

```json
{
  "velux": "1.0",
  "language": "CXX",
  "version": "23",
  "type": "executable",
  "output": "final_exe_name_here",
  "compilers": [
    "clang++"
  ],
  "find-pkg": [],
  "flags": [
    "-Wall",
    "-Werror"
  ],
  "sources": [
    "main.cpp"
  ],
  "include": [
    "include_paths_here"
  ],
  "dependencies": [
    "other_velux_projects_here"
  ]
}
```

You may leave a field blank (or remove) if it does not apply to you.

Languages:

- CXX = C++
- C = C

`find-pkg`:
This will use pkg-conf to configure libraries for you (e.g. `gtk4`)

Then to build, run: `velux` in your terminal!

## Installation / Updating

Run this in your terminal:

```shell
sudo rm -rf /tmp/velux/
git clone https://github.com/thoq-jar/velux.git /tmp/velux && \
cd /tmp/velux && cmake -S . -B build && cmake --build build -j16 && \
sudo mv build/velux /usr/local/bin/velux && rm -rf /tmp/velux && cd $HOME
```

## Roadmap

- [x] Implement dependencies (link other builds together for modularization)
- [x] Implement pkg-config for linking when requested

## License
> © 2025 Thoq-jar

This project uses the MIT license,
see the [LICENSE](LICENSE) for more details.
