# assembly-programs

Two CLI programs written in NASM for DOS.

## 1. Expression evaluator (`calc.asm`)
- Evaluates a mathematical expression
- Supports integers and operations such as addition, subtraction, multiplication, division and controlling an order of operations with parentheses. The maximum expression length is 25 characters 
- Operates on 16-bit numbers, so operands greater than 65535 may produce an incorrect result also a result greater than 65535 may be incorrect
- Includes an input validation, it specifies what is wrong with an expression
- Shows valid expression in Reverse Polish Notation (RPN), also known as postfix notation.

## 2. Caesar cipher (`caesar.asm`)
- Encrypts a string using the Caesar cipher with a given shift
- Supports plaintext strings up to 24 characters long and a shift of less than 65536. When the shift reaches the end of the alphabet, it wraps around to the beginning.

## Requirements
- an x86 processor with 32-bit instruction support (80386 or later), the Caesar cipher also requires MMX support
- DOS
- NASM assembler

Alternatively, an emulator is sufficient. DOSBox-X is recommended because it supports MMX unlike standard DOSBox.

## Usage
Assemble an .asm file using NASM:
```
nasm -o <output>.com -f bin <input>.asm
```
and run the output .com file.

## License
These programs are licensed under the MIT License.