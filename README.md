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

Type "orch help" to get the list of commands and "orch help <command>" to get list of options for a given command.

The general usecase is to run "orch deploy <job_spec>" to deploy a configuration to to Marathon or Chronos.  A given job_spec can contain specifications for many jobs and for multiple environments.  Various options to the deploy command gives control to exactly what is deployed. 

## Job spec format

TODO: describe the file

## Configuration Options

Run the following command to interactively create a config file.
```
$> orch config
```

The file ~/.orch/config.yaml can contain the following values:
cronos_url: http://my.instance.of.chronos
marathon_url: http://my.instance.of.marathon

## Examples

TODO: show some examples

## Contributing

1. Fork it ( https://github.com/[my-github-username]/orch/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
