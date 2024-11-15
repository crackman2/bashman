## --- TODO ---
## -> add support for directories



import os, base64, math, strutils, osproc, zippy, math

if paramCount() < 2:
    echo "Version 0.2 by crackman2"
    echo "Usage:   bashman [input file] [output file] [options] [message (m)]"
    echo "Example: bashman file.exe     file.sh       mizzzx    Hello World!"
    echo " Generates batch script that drops the input file"
    echo " Options:"
    echo ""
    echo "output file"
    echo "  -r        Run file after dropping"
    echo "  -i        Enables progress indicator in batch file (WARNING, bloat)"
    echo "  -m        Enables start message"
    echo "  -x        Delete batch script after execution"
    echo "  -d        Delete dropped file after execution"
    echo "  -c        Disable compression"
    echo "  -z        Increase chunksize (doubles 8K for each z)"
    echo ""
    echo "generation"
    echo "  -v        Disables printing the progress while generating"
    
    quit(0)


if not fileExists(paramStr(1)):
    echo "Error: File not found [", paramStr(1), "]"
    quit(0)


var
    opt_execute    = false  #r
    opt_indicator  = false  #i
    opt_progress   = true   #v
    opt_messages   = false  #m
    opt_suicide    = false  #x
    opt_delete     = false  #d
    opt_compress   = true   #c
    opt_sizefactor = 0      #z

if paramCount() > 2:
    var opt:string = paramStr(3)
    opt = opt.toLower()

    for i in opt:
        case i:
        of '-':
            continue
        of 'z':
            continue
        of 'r':
            opt_execute = true
        of 'i':
            opt_indicator = true
        of 'v':
            opt_progress = false
        of 'm':
            opt_messages = true
        of 'x':
            opt_suicide = true
        of 'd':
            opt_delete = true
        of 'c':
            opt_compress = false
        else:
            echo "Error: Invalid option [",i,"]. Run bashman without arguments for help"
            quit(0)
    
    opt_sizefactor = opt.count('z')



## chunking the data was required in the original batchman
## because batchfiles don't seem to handle large variables
## with about 8096 chars being the limit (?)
## it may not be required anymore but i am not sure yet
var
    input_name = paramStr(1)
    input_perms = ""
    output_name = paramStr(2)
    input_data = readFile(input_name).encode()
    input_data_len = len(input_data)
    result_data = ""
    
    max_chunk_length = 8192
    chunk_byte_index = 0       
    chunk_byte_index_label = 0 # Label current datachunk in final batchfile

    trash = 0 # used because _ didn't

## each occurance of z doubles the chunk size
if opt_sizefactor > 0:
  max_chunk_length = max_chunk_length * pow(2,opt_sizefactor.float).int

  echo "Chunk size: [", max_chunk_length , " B | ", max_chunk_length div 1000, " KB | ", max_chunk_length div 1000000, " MB]"

if opt_compress:
    input_data = compress(input_data)
    input_data = encode(input_data)
    input_data_len = len(input_data)


result_data &= "#!/bin/bash\n"
if opt_messages:
    var msg_txt = ""
    for i in 4..paramCount():
        msg_txt &= paramStr(i) & " "
    result_data &= "echo '" & msg_txt & "'\n"
if opt_indicator: result_data &= "x=\".\"\n" & "p() { echo -n .; }\n"

(input_perms, trash) = execCmdEx("stat --format=%a '" & input_name & "'")

var
    current_progress = 0
    last_progess = 0

## Assign base64 data in chunks using set command
while true:

    ## Check if the next chunk is going beyond EOF
    if(chunk_byte_index+max_chunk_length < input_data_len):
        var cache = ""
        for i in chunk_byte_index..<chunk_byte_index+max_chunk_length:
            cache &= input_data[i]
        result_data &= "d" & $chunk_byte_index_label & "=" & cache & "\n"


    else: ## Write last chunk
        var cache = ""
        for i in chunk_byte_index..<input_data_len:
            cache &= input_data[i]
        result_data &= "d" & $chunk_byte_index_label & "=" &
                cache & "\n"
        break
    
    if opt_indicator: result_data &= "p\n"
    
    inc(chunk_byte_index_label)
    chunk_byte_index+=max_chunk_length

    if opt_progress:
        current_progress = int(math.ceil((chunk_byte_index / input_data_len)*100))
        if current_progress != last_progess:
            last_progess = current_progress
            stdout.write("\rProgress: " & $current_progress & "%")
if opt_progress: stdout.write("\rProgress 100%")

if opt_indicator: result_data &= "echo\n"

#result_data &= "en=$PWD/enf.txt\n"


## Use <nul (set /p =%datachunk%) to avoid whitespace when piping output to encoded_file.txt
for i in 0..chunk_byte_index_label:
    result_data &= "echo -n $d" & $i & " >> enf.txt\n"


## when compression is enabled (default) the base64 data in the bash script
## will first decode the base64 data in enf.txt and save it as a .gz file
## then gzip decompresses it which reveals the original base64 data from the
## input file. thisis then again decoded to yield the input file
if opt_compress:
    result_data &= "base64 -d enf.txt > \"" & input_name & ".gz\"\n"
    result_data &= "gzip -d " & "\"" & input_name & ".gz\"\n"
    result_data &= "mv '" & input_name & "' '" & input_name & ".tmp'\n"
    result_data &= "base64 -d \"" & input_name & ".tmp\" > \"" & input_name & "\"\n"
    result_data &= "rm '" & input_name & ".tmp'\n"
else:
    result_data &= "base64 -d enf.txt > \"" & input_name & "\"\n"

result_data &= "rm enf.txt\n"
result_data &= "chmod " & input_perms.replace("\n", "") & " \"" & input_name & "\"\n"
if opt_execute: result_data &= "./\"" & input_name & "\"\n" ## Execute the resulting file
if opt_delete : result_data &= "rm \"" & input_name & "\"\n"
if opt_suicide: result_data &= "rm \"$0\"\n"


echo "\nSaving to file..."
writeFile(output_name, result_data)
discard execCmd("chmod +x " & "\"" & output_name & "\"")
echo "File written '", output_name, "' Size [", len(result_data), " B | ", len(result_data) div 1000, " KB | ", len(result_data) div 1000000, " MB]"
