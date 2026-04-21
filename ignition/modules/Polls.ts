import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("PollsModule", (m) => {
  const polls = m.contract("Polls");
  return { polls };
});
