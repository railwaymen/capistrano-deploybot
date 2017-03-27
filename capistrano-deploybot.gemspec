Gem::Specification.new do |s|
  s.name        = 'capistrano-deploybot'
  s.version     = '0.0.1'
  s.homepage    = 'https://github.com/kbackowski/capistrano-deploybot'
  s.description = 'Notify slack channel with list of deployed commits'
  s.date        = '2017-03-07'
  s.summary     = 'Capistrano deploy integration for slack'
  s.authors     = ['Kamil Baćkowski']
  s.email       = 'kbackowski@gmail.com'
  s.files       = `git ls-files`.split($/)
  s.license     = 'MIT'

  s.add_dependency 'capistrano', '>= 3.5.0'
end
