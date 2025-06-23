# ft\_lex

**ft\_lex** is a full-featured reimplementation of the classic `lex` utility, built as part of the 42 school curriculum. It adheres strictly to the [POSIX 2024 specification](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/lex.html), covering all required features and bonus challenges.

---

## 🧠 Overview

`ft_lex` is a lexical analyzer generator that transforms `.l` files (Lex source files) into efficient C or Zig source code capable of scanning and tokenizing input streams. The core of this project involves implementing the full lex pipeline from regular expression parsing to optimized scanner generation.

---

## ✨ Features

### ✅ POSIX 2024 Compliance

* Fully supports Extended Regular Expressions (ERE) as defined by POSIX.
* Implements all POSIX-defined scanner macros and functions:

  * `input()`, `unput()`, `yywrap()`, `yymore()`, `yyless()`
  * Start conditions with `BEGIN` and `exclusive`/`inclusive` modes
  * Trailing context with `/`, and anchors `^` and `$`
  * Action control keywords like `REJECT`

### ⚙️ Internal Architecture

* **Tokenizer & Parser** for Lex ERE grammar
* **AST Construction** from regex rules
* **Thompson's Construction** to generate NFAs from ASTs
* **Subset Construction** to convert NFAs into a unified DFA
* **DFA Minimization** using Moore’s algorithm
* **DFA Compression** using the Triple Array Trie method (`base`, `check`, `next`, `default` arrays)

### 🧩 Modular Scanner Generation

* Uses a **template system** to generate scanners modularly.
* The generated scanner adapts to only include the features the user’s `.l` file actually uses.
* Output language is **C by default**, with a **Zig target** also supported as a bonus.

### 🚀 Bonus Features

* ✅ **Zig Scanner Generation** – in addition to standard C
* ✅ **Triple Array Trie Compression** – reduces memory footprint and improves scanning performance for large DFAs
* ✅ **Graph Output (`-g` flag)** – generates `.dot` files representing the NFA and DFA for each start condition, useful for visualization with Graphviz

---

## 📦 Installation & Usage

This project is written entirely in **Zig**. To build:

```bash
zig build libl
zig build
```

To run the lexical analyzer generator:

```bash
./zig-out/bin/ft_lex input.l
```

To see all available options:

```bash
./zig-out/bin/ft_lex --help
```

### Example

To generate a scanner and compile it:

```bash
./zig-out/bin/ft_lex input.l
cc -o scanner ft_lex.yy.c src/libl/libl.a
./scanner < input.txt
```

---

## 🧪 Examples

Check the `examples/` directory for `.l` files demonstrating:

* Use of `REJECT`, `yymore()`, `yyless()`
* Multiple start conditions
* Anchors and trailing context
* Manual control of the input stream with `input()` and `unput()`

---

## ⚠️ Performance Notes

* Use of features like `REJECT`, `yymore()` or trailing contexts (`/`) may significantly increase DFA size and complexity.
* This can result in larger generated tables and slower execution times, just like in original `lex`/`flex` implementations.

---

## 📚 References

* [POSIX `lex` Specification (2024)](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/lex.html)
* Aho, Sethi, Ullman – *Compilers: Principles, Techniques, and Tools*
* *flex* source code for comparison and compliance behavior

---

## 👨‍💻 Author

**Bryan VAN PAEMEL** – [github.com/BrimVeyn](https://github.com/BrimVeyn)

---

## 🏫 42 Project

This project was completed as part of the 42 school's advanced UNIX curriculum. All mandatory and bonus objectives have been implemented.
