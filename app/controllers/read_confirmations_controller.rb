class ReadConfirmationsController < BaseController
  READ_ONLY_MAINTENANCE_ENV = "READ_ONLY_MAINTENANCE"

  def create
    document = Document.find_by!(public_id: read_confirmation_params[:document_id])
    require_document_access!(document)

    if read_only_maintenance_mode?
      redirect_to_back alert: maintenance_read_confirmation_message
      return
    end

    current_user.read_confirmations.find_or_initialize_by(document:).tap do |confirmation|
      confirmation.document_version = document.latest_version
      confirmation.confirmed_at = Time.current
      confirmation.save!
    end

    redirect_to_back notice: "既読にしました。"
  end

  def destroy
    confirmation = current_user.read_confirmations.find_by!(public_id: params[:public_id])

    if read_only_maintenance_mode?
      redirect_to_back alert: maintenance_read_confirmation_message
      return
    end

    confirmation.destroy!

    redirect_to_back notice: "既読を解除しました。"
  end

  private

  def read_confirmation_params
    params.require(:read_confirmation).permit(:document_id)
  end

  def read_only_maintenance_mode?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(READ_ONLY_MAINTENANCE_ENV, nil))
  end

  def maintenance_read_confirmation_message
    "メンテナンス中のため既読確認の変更は停止しています。文書閲覧と既読確認内訳の確認は継続できます。"
  end
end
