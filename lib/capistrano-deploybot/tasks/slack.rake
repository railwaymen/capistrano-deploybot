namespace :slack do
  namespace :deploy do
    desc 'Notify about updated deploy'
    task :updated do
      CapistranoDeploybot::Capistrano.new(self).run
    end
  end
end

# before 'deploy', 'slack:deploy:updated'
after 'deploy:finishing', 'slack:deploy:updated'
