@{
	Path = "PrometheusForge.psd1";
	OutputDirectory = "build";
	UnversionedOutputDirectory = "true";
	# Extra files the module needs at runtime (ModuleBuilder only compiles the code folders)
	CopyPaths = @("Formats");
}
