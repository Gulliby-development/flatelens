<p align="center"><img src="docs/logo.svg" width="96" alt="" /></p>

# flatelens

flatelens is an offline command-line inspector for raw DEFLATE (RFC 1951), zlib (RFC 1950), and gzip (RFC 1952) streams. It decodes the stream itself; it does not require a zlib binding, external runtime package, or network connection. It is intended for people debugging compressors, archive writers, and network code who need to inspect compressed data, block structure, Huffman trees, decoded bytes, and validation problems.

The program requires Lua 5.4 and uses only its standard library at runtime. Inputs may be binary files or text files containing hexadecimal bytes.

[![CI](https://github.com/Gulliby-development/flatelens/actions/workflows/ci.yml/badge.svg)](https://github.com/Gulliby-development/flatelens/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Install and run

Install Lua 5.4 using the package manager for your platform. Install Busted with LuaRocks for running the test suite:

~~~sh
luarocks install busted
~~~

Get the project:

~~~sh
git clone https://github.com/Gulliby-development/flatelens.git
cd flatelens
~~~

Busted is a development/test dependency only; flatelens itself has no third-party runtime dependencies. From the repository root, launch it with:

~~~sh
lua bin/flatelens.lua info --hex hello.hex
~~~

In the examples below, `flatelens` means the command `lua bin/flatelens.lua`. To run them as written in a POSIX shell (Git Bash on Windows), define this shorthand in the project directory:

~~~sh
flatelens() { lua bin/flatelens.lua "$@"; }
~~~

The examples use a POSIX-style shell with `printf` to create hex fixtures. On Windows, run these fixture commands in Git Bash or WSL (or another shell that provides compatible `printf`); `cmd.exe` does not provide the same `printf` command.

## Usage

~~~text
usage: flatelens info [--format F] [--hex] FILE
       flatelens blocks [--format F] [--hex] FILE
       flatelens tree [--format F] [--hex] [--block N] FILE
       flatelens dump [--format F] [--hex] [--skip N] [--limit N] FILE
       flatelens check [--format F] [--hex] FILE...
       flatelens codes LENGTH...
~~~

The format defaults to `auto`. Auto detection selects gzip for the `1f 8b` magic, zlib for a valid zlib header, and raw DEFLATE otherwise. Use `--format auto`, `gzip`, `zlib`, or `raw` to select a format explicitly. `--hex` treats the input file as UTF-8 hexadecimal text; without it, input files are read as binary.

Options can appear before or after file operands. `--hex` is a flag. `--format F` selects a format. A file operand `-` reads standard input, and is supported only with `--hex` because Lua's Windows text-mode standard input cannot preserve arbitrary binary bytes.

- `info [--format F] [--hex] FILE` reports the format, container metadata, block summary, compressed and decoded sizes, ratio, checksum status, and trailing bytes when present.
- `blocks [--format F] [--hex] FILE` prints each decoded block's kind, final flag, positions, bit count, output count, literals, and matches.
- `tree [--format F] [--hex] [--block N] FILE` summarizes each dynamic block's transmitted code-length lengths, literal/length and distance lengths, and tree statistics. `--block N` selects one 1-based block.
- `dump [--format F] [--hex] [--skip N] [--limit N] FILE` prints decoded bytes as a 16-byte-per-line hex dump. The default skip is 0 and the default limit is 256 bytes; skip must be non-negative and limit must be at least 1.
- `check [--format F] [--hex] FILE...` checks every operand, continuing after read or decoding problems. It reports each stream's problems and summarizes the number of successfully read files and problems.
- `codes LENGTH...` builds a canonical Huffman code from lengths 0 through 15. A length may be written as `L` or `LxN` for N repetitions (1–288); at most 288 lengths are accepted.
- `codes SYMBOL:LENGTH...` builds the code from the symbol lists that `tree` prints. An operand is `S:L` (symbol S has length L) or `A-B:L` (symbols A through B have length L); symbols 0 through 287 and lengths 0 through 15 are accepted, unlisted symbols get length 0, and a symbol may be listed once. The first operand chooses the form: if it contains a colon, every operand must use this form.

A position is written `BYTE.BIT` and is zero-based from the beginning of the file. For example, `1.2` means bit 2 (least-significant bit is bit 0) of byte 1, and `9.0` means byte 9.

Successful commands exit 0. A stream problem normally exits 1. Command-line errors and inputs that cannot be read or decoded as hex text exit 2. When decoding stops early, `info` prints the known header and block summary, while `blocks` and `tree` print blocks completed before the problem; `dump` prints no partial dump. `check` handles all operands even when one cannot be read: successfully read operands are counted, and exit 2 takes precedence over exit 1 if any read/hex error occurred. Problems for `check` are printed on standard output; other stream commands write problems to standard error.

## Examples

Create the hex file for the info example:

~~~sh
printf '78 9c cb 48 cd c9 c9 07 00 06 2c 02 15\n' > hello.hex
~~~

~~~text
$ flatelens info --hex hello.hex
format: zlib
window: 32768 bytes
level: default
blocks: 1 (1 fixed)
compressed: 7 bytes
uncompressed: 5 bytes
ratio: 140.0%
check: adler32 ok
~~~

Create both fixtures for the check example:

~~~sh
printf '78 9c cb 48 cd c9 c9 07 00 06 2c 02 15\n' > hello.hex
printf '78 9c cb 48 cd c9 c9 07 00 06 2c 02 14\n' > bad.hex
~~~

~~~text
$ flatelens check --hex hello.hex bad.hex
hello.hex: ok
bad.hex: FL021 Adler-32 mismatch: stored 0x062c0214, computed 0x062c0215 at 9.0
checked 2 files, 1 problem
~~~

The `blocks` example uses three raw-DEFLATE blocks:

~~~sh
printf '00 04 00 fb ff 61 61 61 61 00 00 00 ff ff 4b 4a 82 00 00\n' > two.hex
~~~

~~~text
$ flatelens blocks --hex two.hex
block 1: stored, start 0.0, 72 bits, 4 bytes out, 0 literals, 0 matches
block 2: stored, start 9.0, 40 bits, 0 bytes out, 0 literals, 0 matches
block 3: fixed, final, start 14.0, 38 bits, 8 bytes out, 2 literals, 1 match
~~~

The tree and dump examples share this compressed text fixture:

~~~sh
printf '78 da 75 cb d1 09 80 30 0c 45 d1 55 de 00 e2 1e 8e d1 ea ab 09 b4 46 4c a0 eb 4b bf 44 d0 ef 73 ef 12 e8 c9 11 42 64 7a c0 0a 42 1b 7d 82 3e d2 ed fa a3 b4 73 40 57 df ac 7d 49 31 ab ea 72 d0 df 23 4f 5b 65 04 99 55 59 66 dc 0c 4f 2f f6\n' > text.hex
~~~

~~~text
$ flatelens tree --hex text.hex
block 1: dynamic, HLIT 271, HDIST 12, HCLEN 18
code length code lengths: 16:0 17:5 18:3 0:2 8:0 7:0 9:0 6:2 10:0 5:3 11:0 4:3 12:0 3:5 13:0 2:5 14:0 1:5
literal/length lengths: 32:3 44:6 46:6 73:6 97-98:5 99-100:6 101:3 102:5 103:6 104-105:4 108-109:5 110:6 111:4 112:6 114:6 115-116:4 119:5 256:6 258:5 264:6 266:6 269-270:6
distance lengths: 9:1 10-11:2
literal/length code: 28 symbols, max length 6, complete
distance code: 3 symbols, max length 2, complete
~~~

~~~text
$ flatelens dump --hex --skip 4 --limit 40 text.hex
00000004  61 73 20 74 68 65 20 62 65 73 74 20 6f 66 20 74  |as the best of t|
00000014  69 6d 65 73 2c 20 69 74 20 77 61 73 20 74 68 65  |imes, it was the|
00000024  20 77 6f 72 73 74 20 6f                          | worst o|
... 94 bytes more
~~~

The RFC canonical-code example uses no input file:

~~~text
$ flatelens codes 3 3 3 3 3 2 4 4
0: 3 010
1: 3 011
2: 3 100
3: 3 101
4: 3 110
5: 2 00
6: 4 1110
7: 4 1111
status: complete (16/16)
~~~

The symbol lists printed by `tree` can be used directly:

~~~text
$ flatelens codes 9:1 10-11:2
9: 1 0
10: 2 10
11: 2 11
status: complete (4/4)
~~~

## Problem codes

The `check` command prints a code, explanation, and zero-based bit position for each problem. Header and DEFLATE problems stop decoding; trailer mismatches and trailing data are reported without undoing decoded output. There is no FL009.

| Code | Meaning |
| --- | --- |
| FL001 | Unexpected end of data; the position is the file length in bytes with bit 0. |
| FL002 | Unsupported compression method. |
| FL003 | Reserved gzip flag bits are set. |
| FL004 | The zlib header check failed. |
| FL005 | The zlib window size is too large (CINFO exceeds 7). |
| FL006 | A zlib preset dictionary is required. |
| FL007 | The gzip header CRC does not match. |
| FL008 | The input does not have gzip magic bytes when gzip is requested. |
| FL010 | Reserved DEFLATE block type 3. |
| FL011 | Stored-block LEN and NLEN do not complement one another. |
| FL012 | HLIT or HDIST specifies too many length or distance symbols. |
| FL013 | The code-length Huffman code is incomplete or over-subscribed. |
| FL014 | A code-length repeat is invalid, has no previous length, or exceeds the required entries. |
| FL015 | The literal/length tree has no end-of-block symbol (256). |
| FL016 | The literal/length Huffman code is incomplete or over-subscribed. |
| FL017 | The distance Huffman code is incomplete or over-subscribed. |
| FL018 | An invalid literal/length symbol was encountered. |
| FL019 | An invalid distance symbol was encountered. |
| FL020 | A distance reaches farther back than the bytes written so far. |
| FL021 | A gzip CRC-32 or zlib Adler-32 checksum does not match. |
| FL022 | The gzip uncompressed-size trailer does not match. |
| FL023 | Bytes remain after the end of the stream. |

## Development

From the repository root, run the test suite and static checks:

~~~sh
busted
luacheck .
stylua --check .
~~~

Install the tools with `luarocks install busted` and `luarocks install luacheck`; StyLua is a single binary from the [StyLua releases](https://github.com/JohnnyMorganz/StyLua/releases). To format Lua files, run `stylua .`. The tests use Busted, installed separately from the standard-library-only runtime. Keep examples and fixtures offline; the program does not use the network.

## License

MIT, see [LICENSE](LICENSE).

---

Built with BAKED
