# Orch

orch - uses a Yaml file to specify jobs that can be delpoyed to Mesos' Marathon and Chronos frameworks.

## Installing this tool

Run the following command
$> gem install orch
(Protip: you might need to sudo)
Once the gem is installed, the command orch will be in your $PATH

## Usage

TODO: Write usage instructions here

## Job spec format

TODO: describe the file

## Configuration Options

The file ~/.orch/config.yaml can contain the following values:
cronos_url: http://my.instance.of.chronos
marathon_url: http://my.instance.of.marathon

## Contributing

1. Fork it ( https://github.com/[my-github-username]/orch/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
