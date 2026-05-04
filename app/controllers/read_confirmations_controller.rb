class ReadConfirmationsController < BaseController
  def create
    document = Document.find_by!(public_id: read_confirmation_params[:document_id])
    require_document_access!(document)

    current_user.read_confirmations.find_or_initialize_by(document:).tap do |confirmation|
      confirmation.document_version = document.latest_version
      confirmation.confirmed_at = Time.current
      confirmation.save!
    end

    redirect_to_back notice: "既読にしました。"
  end

  def destroy
    confirmation = current_user.read_confirmations.find_by!(public_id: params[:public_id])
    confirmation.destroy!

    redirect_to_back notice: "既読を解除しました。"
  end

  private

  def read_confirmation_params
    params.require(:read_confirmation).permit(:document_id)
  end
end
