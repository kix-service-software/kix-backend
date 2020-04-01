#!/bin/bash

API_MODULES=$(cd Kernel/Config/Files/API && grep -roPh "\"Operation::Module#.*?\"")

echo $API_MODULES
