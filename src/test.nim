import os

let newTitle = "caulk"
var terminalTitle = "#!/bin/bash\necho -e '\033]0;" & newTitle & "\007'" & "\n"

terminalTitle &= "x=\".\"\n"
terminalTitle &= "echo $x"

writeFile("testfile.txt",terminalTitle)