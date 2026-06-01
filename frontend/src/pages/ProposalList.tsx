import ProposalListComponent from '../components/ProposalList';
import { sampleProposals } from '../data';

export default function ProposalList() {
  return <ProposalListComponent proposals={sampleProposals} />;
}
