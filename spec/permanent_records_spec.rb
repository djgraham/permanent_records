require 'spec_helper'

describe PermanentRecords do

  let!(:frozen_moment) { Time.now                            }
  let!(:dirt)          { Dirt.create!                        }
  let!(:earthworm)     { dirt.create_earthworm               }
  let!(:hole)          { dirt.create_hole                    }
  let!(:muskrat)       { hole.muskrats.create!               }
  let!(:mole)          { hole.moles.create!                  }
  let!(:location)      { hole.create_location                }
  let!(:difficulty)    { hole.create_difficulty; pp hole.difficulty; hole.difficulty              }
  let!(:comments)      { 2.times.map {hole.comments.create!} }
  let!(:kitty)         { Kitty.create!                       }


  describe '#destroy' do

    let(:record)       { hole    }
    let(:should_force) { false   }
    subject { record.destroy should_force }

    it 'returns the record' do
      subject.should == record
    end

    it 'makes deleted? return true' do
      subject.should be_deleted
    end

    it 'sets the deleted_at attribute' do
      subject.deleted_at.should be_with(0.1).of(Time.now)
    end

    it 'does not really remove the record' do
      expect { subject }.to_not change(record.class.count)
    end

    context 'with force argument set to truthy' do
      let(:should_force) { :force }

      it 'does really remove the record' do
        expect { subject }.to change(record.class.count, -1)
      end
    end

    context 'when model has no deleted_at column' do
      let(:record) { kitty }

      it 'really removes the record' do
        expect { subject }.to change(record.class.count, -1)
      end
    end

    context 'with dependent records' do
      context 'that are permanent' do
        it '' do
          expect { subject }.to_not change(Muskrat.count)
        end

        context 'with has_many cardinality' do
          it 'marks records as deleted' do
            subject.muskrats.each {|m| m.should be_deleted }
          end
          context 'with force delete' do
            let(:should_force) { :force }
            it('') { expect { subject }.to change(Muskrat.count, -1) }
            it('') { expect { subject }.to change(Comment.count, -2) }
          end
        end

        context 'with has_one cardinality' do
          it 'marks records as deleted' do
            subject.location.should be_deleted
          end
          context 'with force delete' do
            let(:should_force) { :force }
            it('') { expect { subject }.to change(Muskrat.count, -1) }
            it('') { expect { subject }.to change(Location.count, -1) }
          end
        end
      end
      context 'that are non-permanent' do
        it 'removes them' do
          expect { subject }.to change(Mole.count, -1)
        end
      end
      context 'as default scope' do
        context 'with :has_many cardinality' do
          its('comments.size') { should == 2 }
          it 'deletes them' do
            subject.comments.each {|c| c.should be_deleted }
            subject.comments.each {|c| Comment.find_by_id(c.id).should be_nil }
          end
        end
        context 'with :has_one cardinality' do
          it 'deletes them' do
            subject.difficulty.should be_deleted
            Difficulty.find_by_id(subject.difficulty.id).should be_nil
          end
        end
      end
    end
  end

  describe '#revive' do

    let!(:record) { hole.destroy }
    subject { record.revive }

    it 'returns the record' do
      subject.should == record
    end

    it 'unfreezes the record' do
      expect { subject }.to change {
        record.frozen?
      }.from(true).to(false)
    end

    it 'unsets deleted_at' do
      expect { subject }.to change {
        record.deleted_at
      }.to(nil)
    end

    it 'makes deleted? return false' do
      subject.should_not be_deleted
    end

    context 'when validations fail' do
      before { record.
                should_receive(:valid?).
                and_return(false) }
      it 'raises' do
        expect { subject }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'with dependent records' do
      context 'that are permanent' do
        it '' do
          expect { subject }.to_not change { Muskrat.count }
        end

        context 'that were deleted previously' do
          before { muskrat.update_attributes! :deleted_at => 2.minutes.ago }
          it 'does not restore' do
            expect { subject }.to_not change { muskrat.deleted? }
          end
        end

        context 'with has_many cardinality' do
          it 'revives them' do
            subject.muskrats.each {|m| m.should_not be_deleted }
          end
        end

        context 'with has_one cardinality' do
          it 'revives them' do
            subject.location.should_not be_deleted
          end
        end
      end
      context 'that are non-permanent' do
        it 'revives them' do
          expect { subject }.to change(Mole.count, 1)
        end
      end
      context 'as default scope' do
        context 'with :has_many cardinality' do
          its('comments.size') { should == 2 }
          it 'revives them' do
            subject.comments.each {|c| c.should_not be_deleted }
            subject.comments.each {|c| Comment.find_by_id(c.id).should == c }
          end
        end
        context 'with :has_one cardinality' do
          it 'revives them' do
            subject.difficulty.should_not be_deleted
            Difficulty.find_by_id(subject.difficulty.id).should == difficulty
          end
        end
      end
    end
  end

  describe 'scopes' do

    before {
      Muskrat.delete_all
      ActiveRecord::Base.logger.info "about to setup"
      3.times { Muskrat.create! }
      6.times { Muskrat.create!.destroy }
    }
    after { Muskrat.delete_all }

    context '.not_deleted' do

      it 'counts' do
        Muskrat.not_deleted.count.should == 3
      end

      it 'has no deleted records' do
        Muskrat.not_deleted.each {|m| m.should_not be_deleted }
      end
    end

    context '.deleted' do

      it 'counts' do
        Muskrat.deleted.count.should == 4
      end

      it 'has no non-deleted records' do
        Muskrat.deleted.each {|m| m.should be_deleted }
      end

    end

    context '.deleted' do
      it 'counts' do
        p Muskrat.not_deleted.count
        p Muskrat.deleted.count
        Muskrat.not_deleted.count.should == 3
      end
    end

    it '.not_deleted' do
      Muskrat.deleted.each {|m| m.should be_deleted }
    end
  end
end
