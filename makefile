ODIR=build/PrometheusForge
ONAME=PrometheusForge

ifeq ($(OS),Windows_NT)
	# Generic Windows settings
	CMD_PWSH=C:\Windows\SysNative\WindowsPowerShell\v1.0\powershell.exe
	CMD_DEL=del
	
	# Architecture-specific settings
    # CCFLAGS += -D WIN32
    ifeq ($(PROCESSOR_ARCHITEW6432),AMD64)
        # CCFLAGS += -D AMD64
    else
        ifeq ($(PROCESSOR_ARCHITECTURE),AMD64)
            # CCFLAGS += -D AMD64
        endif
        ifeq ($(PROCESSOR_ARCHITECTURE),x86)
            # CCFLAGS += -D IA32
        endif
    endif
else
	# Generic *NIX settings
	CMD_PWSH=pwsh
	CMD_DEL=rm
	
	# Architecture-specific settings
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
        # CCFLAGS += -D LINUX
    endif
    ifeq ($(UNAME_S),Darwin)
        # CCFLAGS += -D OSX
    endif
    UNAME_P := $(shell uname -p)
    ifeq ($(UNAME_P),x86_64)
        # CCFLAGS += -D AMD64
    endif
    ifneq ($(filter %86,$(UNAME_P)),)
        # CCFLAGS += -D IA32
    endif
    ifneq ($(filter arm%,$(UNAME_P)),)
        # CCFLAGS += -D ARM
    endif
endif


SHELL_CMD = \
try { \
    Import-Module ./$(ODIR)/$(ONAME).psd1 -ErrorAction Stop \
} catch { \
    $$err = $$Error[0] | Select-Object *; \
    Write-Output $$err; \
    try { \
        $$trace = ($$err.ScriptStackTrace -split [System.Environment]::NewLine)[0]; \
        Write-Output $$trace; \
        Write-Output $$(ConvertTo-SourceLineNumber -PositionMessage $$trace) \
    } catch {Write-Output "Failed to convert script stack trace to source line number."} \
}
#        Write-Output ($$err.Exception.Message -split [System.Environment]::NewLine)[0] | ConvertTo-SourceLineNumber \


all: build-module

shell: doShell
# shell: build-module doShell

test: doTest
# test: build-module doTest

test-function: doTestFunction
# test-function: build-module doTestFunction

production: doInstallProduction
# production: doInstallProduction

dev: doInstallDevelopment
# dev: doInstallDevelopment

build-module:
	$(CMD_PWSH) -c 'Build-Module'

doShell:
	$(CMD_PWSH) -noe -c '$(SHELL_CMD)'

doTest:
	$(CMD_PWSH) -c 'Import-Module ./$(ODIR)/$(ONAME).psd1;Invoke-Pester;exit'

doTestFunction:
	$(CMD_PWSH) -c 'Import-Module ./$(ODIR)/$(ONAME).psd1;test -Verbose -Debug'

doInstallProduction:
	$(CMD_PWSH) -c 'Import-Module ./$(ODIR)/$(ONAME).psd1;Install-Module -Name powershell-yaml -MinimumVersion 0.4.12 -Scope CurrentUser -Force'

doInstallDevelopment: doInstallProduction
	$(CMD_PWSH) -c 'Import-Module ./$(ODIR)/$(ONAME).psd1;Install-Module -Name ModuleBuilder -Scope CurrentUser -Force'


clean:
	$(CMD_DEL) $(ODIR)/*
