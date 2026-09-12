# Taskfile + Windows 原生命令的坑

适用于 scripts/winswctl、scripts/winstctl 这类跑在 task 自带 mvdan/sh 上的工具。
以下结论均在本机实证过（2026-09，Win10 19045）。

## schtasks 参数用单斜杠

mvdan/sh 不做 MSYS 式路径转换，双斜杠形式会原样传给 schtasks 被拒
（Invalid argument/option - '//query'）。所有 /tn /xml 等开关写单斜杠。

## schtasks /create /xml 的 XML 声明限制

- 模板首行必须 <?xml version="1.0"?>，不带 encoding 属性
- 声明 encoding="UTF-8"（大小写均试）报 (1,40) unable to switch the encoding
- UTF-8 + BOM 报 (1,2) incorrect document syntax
- 真 UTF-16 + BOM 可用，但 coreutils 管道下生成麻烦，不采用
- Exec/Command 为空会被拒：(24,19):Command incorrectly formatted or out of range，apply 前需检查

## schtasks 管道导出的声明与字节不符

schtasks /query /tn X /xml 重定向落盘的文件声明 encoding="UTF-16"
但字节实为控制台代码页。yq 按声明解码出乱码。import 类命令需先落临时文件、
重写声明行为 <?xml version="1.0"?> 再使用。

## mvdan mktemp 路径不可重定向

task 自带 sh 的 mktemp 返回 /tmp\NNN 混合分隔符路径，重定向打不开。
临时文件用相对路径名（如 .foo.tmp），用完 rm -f。

## errexit 与批量循环

task 的 sh 为 errexit。批量 status 这类单个失败不应中断的循环对命令加 || true
（错误文本仍透传 stderr）；apply/destroy 等同步语义保持失败即停。
