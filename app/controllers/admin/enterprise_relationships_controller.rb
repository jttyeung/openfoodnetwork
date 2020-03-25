module Admin
  class EnterpriseRelationshipsController < ResourceController
    def index
      @my_enterprises = Enterprise.managed_by(spree_current_user).by_name
      @all_enterprises = Enterprise.by_name
      @enterprise_relationships = EnterpriseRelationship.by_name.involving_enterprises @my_enterprises
    end

    def create
      @enterprise_relationship = EnterpriseRelationship.new enterprise_relationship_params

      if @enterprise_relationship.save
        render text: Api::Admin::EnterpriseRelationshipSerializer.new(@enterprise_relationship).to_json
      else
        render status: :bad_request, json: { errors: @enterprise_relationship.errors.full_messages.join(', ') }
      end
    end

    def destroy
      @enterprise_relationship = EnterpriseRelationship.find params[:id]
      @enterprise_relationship.destroy
      render nothing: true
    end

    private

    def enterprise_relationship_params
      params.require(:enterprise_relationship).permit(:parent_id, :child_id, permissions_list: [])
    end
  end
end
