# Orch

orch - uses a Yaml file to specify jobs that can be delpoyed to Mesos' Marathon and Chronos frameworks.

## Installing this tool

Run the following command:
```
$> gem install orch
```
(you might need to sudo)

Once the gem is installed, the command orch will be in your $PATH

## Usage

Type "orch help" to get the list of commands and "orch help _command_" to get list of options for a given command.

The general usecase is to run "orch deploy _job_spec_" to deploy a configuration to to Marathon or Chronos.  A given job_spec can contain specifications for many jobs and for multiple environments.  Various options to the deploy command gives control to exactly what is deployed. 

## Job spec format

The orch Yaml format is really a wrapper for multiple Marathon or Chronos job descriptions.  The format is based on yaml.  To get a basic understanding of Yaml files check out: http://www.yaml.org/start.html

The basic orch syntax is as follows:
```
version: alpha1
applications:
  - kind: Chronos
    chronos_spec:
```

The version: field must currently always be alpha1.  Eventually, this tool may need to support a revised format and this can be used to support multiple versions.

The applications: field contains an array of Chronos or Marathon configurations.  Each array must have a kind: field with a value of Chronos or Marathon which simply tells orch what type of config this is.  Depending on the value of kind: a field of chronos_spec: or marathon_spec: is also required.

The values of chronos_spec: should simply be the yaml equivelent of the chronos json messages.  You can find documentation for chronos json format here: https://mesos.github.io/chronos/docs/api.html


Likewise, the values of marathon_spec: should simply be the yaml equivelent of the marathon json messages.  You can find documentation for marathon json format here: https://mesosphere.github.io/marathon/docs/rest-api.html

TODO: finish this section

## Configuration Options

Run the following command to interactively create a config file.
```
$> orch config
```

The file ~/.orch/config.yaml would contain values for "chronos_url" and "marathon_url".  You can also pass --chronos_url or --marathon_url options to the "orch deploy" command to override what is in the config file.

## Examples

The examples directory contains various examples of the features of orch.  
View [documentation there](examples/Examples.md) for more details.

## Contributing

1. Fork it ( https://github.com/[my-github-username]/orch/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
