module RedmineBetterFiles
  module FilesPaginationPatch
    def self.included(base)
      base.send(:include, InstanceMethods)

      base.class_eval do 
        # Below filter changes are to allow global /files view:
        # remove :find_project_by_project_id, which selects @project and raises an exception if params[:project_id] is not specified,
        # remove :authorize filter, 
        # add :find_optional_project, which would let @project == nil
        # and add :authorize back but less restrictive
        skip_before_filter :find_project_by_project_id
        skip_before_filter :authorize
        before_filter :find_optional_project
        before_filter :authorize, :except => [:index]
        
        alias_method_chain :index, :pagination
      end
    end

    module InstanceMethods
      # To allow pagination on files I have to refuse from Project Versions separation so far
      def index_with_pagination
        sort_init 'filename', 'asc'
        sort_update 'filename' => "#{Attachment.table_name}.filename",
                    'created_on' => "#{Attachment.table_name}.created_on",
                    'size' => "#{Attachment.table_name}.filesize",
                    'downloads' => "#{Attachment.table_name}.downloads"
                
        per_page = params[:per_page].nil? ? Setting.per_page_options_array.first : params[:per_page].to_i
        
        # This should select attachments for current Project and Issues of current project
        # TODO: move to model. Hell, this is ugly.
        if @project.nil?
          basic_query = "select count(distinct a.id) from attachments a, projects p, issues i
                         where (a.container_type = 'Project' and a.container_id = p.id and p.status = 1) 
                         or (a.container_type = 'Issue' and a.container_id = i.id and i.project_id = p.id and p.status = 1)"
          conditions = [basic_query]
        else
           basic_query = "attachments.id in (select a.id from attachments a left join projects p on (p.id = a.container_id) 
                          left join issues i on (i.id = a.container_id) where (p.id = ? and a.container_type = 'Project') or 
                          (a.container_type = 'Issue' and i.project_id = ?))"
           conditions = [basic_query, @project.id, @project.id]
        end
                
        @file_pages, @files = paginate :attachments, 
                              :conditions => conditions,
                              :order => sort_clause,
                              :per_page => per_page
        render :layout => !request.xhr?
      end
    end
  end
end
