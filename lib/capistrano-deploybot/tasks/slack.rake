namespace :slack do
  namespace :deploy do
    desc 'Notify about updated deploy'
    task :updated do
      on roles(:web) do
        within release_path do
          CapistranoDeploybot::Capistrano.new(self).run
        end
      end
    end
  end
end

after 'deploy:finishing', 'slack:deploy:updated'
