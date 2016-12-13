class LocalBuildResult
  include ActiveModel::Model
  attr_accessor :project, :package, :repository, :architecture, :code, :state, :details

  def self.find_by(project, package, repository, architecture)
    find_by_project_and_package(project, package).
      select { |buildresult| buildresult.repository == repository &&
                             buildresult.architecture == architecture
             }
  end

  private

  def self.find_by_project_and_package(project, package)
    buildresults = Buildresult.find_hashed( project: project, package: package, view: 'status', multibuild: '1', locallink: '1')
    local_build_results = []
    buildresults.elements('result').each do |result|
      result.elements('status').each do |status|
        local_build_results << LocalBuildResult.new(project: result['project'],
                                                    package: status['package'],
                                                    repository: result['repository'],
                                                    architecture: result['arch'],
                                                    code: status['code'],
                                                    state: result['state'],
                                                    details: result['details']
                                                   )
      end
    end

    if local_build_results.any? { |build_result| build_result.package.start_with?("#{package}:") }
      local_build_results.reject! { |build_result| build_result.package == package }
    end

    local_build_results
  end
end
