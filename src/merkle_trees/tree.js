const treeUtils = require("./treeUtils.js");
const { pedersen } = require("starknet/utils/hash");

module.exports = class Tree {
  constructor(_leafNodes, depth = treeUtils.getBase2Log(_leafNodes.length)) {
    this.leafNodes = treeUtils.padArrayEnd(_leafNodes, 8, 0);
    this.depth = depth;
    this.innerNodes = this.treeFromLeafNodes();
    this.root = this.innerNodes[0][0];
    // Keep track of zero notes below
    // count = how many notes are set(not zero)
    // zeroIdxs = indexes of notes below index==count that are zero
    this.count = _leafNodes.length;
    this.zeroIdxs = [];
  }

  updateInnerNodes(leaf, idx, merkle_path) {
    // get position of affected inner nodes
    const depth = merkle_path.length;
    const proofPos = treeUtils.proofPos(idx, depth);
    const affectedPos = treeUtils.getAffectedPos(proofPos);
    // get new values of affected inner nodes and update them
    const affectedInnerNodes = treeUtils.innerNodesFromLeafAndPath(
      leaf,
      idx,
      merkle_path
    );

    // update affected inner nodes
    for (var i = 1; i < depth + 1; i++) {
      this.innerNodes[depth - i][affectedPos[i - 1]] =
        affectedInnerNodes[i - 1];
    }

    this.root = this.innerNodes[0][0];

    return { affectedPos, affectedInnerNodes };
  }

  updateLeafNodes(leafHash, idx) {
    this.leafNodes[idx] = leafHash;
  }

  updateNode(leafHash, idx, proof) {
    if (idx > this.count) {
      throw "update previous empty leaves first";
    } else if (idx == this.count) {
      this.count++;
    } else {
      // if this check is too expensive we can use a bloom filter
      this.zeroIdxs = this.zeroIdxs.filter((el) => el !== idx);
    }

    this.updateLeafNodes(leafHash, idx);
    return this.updateInnerNodes(leafHash, idx, proof);
  }

  treeFromLeafNodes() {
    var tree = Array(this.depth);
    tree[this.depth - 1] = treeUtils.pairwiseHash(this.leafNodes);

    for (var j = this.depth - 2; j >= 0; j--) {
      tree[j] = treeUtils.pairwiseHash(tree[j + 1]);
    }
    return tree;
  }

  getProof(leafIdx, depth = this.depth) {
    const proofBinaryPos = treeUtils.idxToBinaryPos(leafIdx, depth);
    const proofPos = treeUtils.proofPos(leafIdx, depth);
    var proof = new Array(depth);
    proof[0] = this.leafNodes[proofPos[0]];
    for (var i = 1; i < depth; i++) {
      proof[i] = this.innerNodes[depth - i][proofPos[i]];
    }
    return {
      proof: proof,
      proofPos: proofBinaryPos,
    };
  }

  getMultiUpdateProof(leafHash, proof, proofBinaryPos) {
    var preimage = new Map();
    var hashes = new Array(proof.length - 1);

    let hash_inp = !proofBinaryPos[0]
      ? [leafHash, proof[0]]
      : [proof[0], leafHash];

    hashes[0] = pedersen(hash_inp);

    preimage.set(hashes[0], hash_inp);

    for (let i = 1; i < proof.length; i++) {
      hash_inp = !proofBinaryPos[i]
        ? [hashes[i - 1], proof[i]]
        : [proof[i], hashes[i - 1]];

      hashes[i] = pedersen(hash_inp);

      preimage.set(hashes[i], hash_inp);
    }

    return preimage;
  }

  verifyProof(leafHash, idx, proof) {
    const computed_root = treeUtils.rootFromLeafAndPath(leafHash, idx, proof);
    return this.root == computed_root;
  }

  verifyRoot() {
    let treeTemp = this.treeFromLeafNodes();
    return this.root == treeTemp[0][0];
  }

  firstNZeroIdxs(n) {
    if (n == 0) {
      return [];
    }

    let idxs = [];
    if (n <= this.zeroIdxs.length) {
      for (let i = 0; i < n; i++) {
        idxs.push(this.zeroIdxs[i]);
      }
    } else {
      idxs.concat(this.zeroIdxs);
      for (let i = 0; i < n - this.zeroIdxs.length; i++) {
        idxs.push(this.count + i);
      }
    }

    return idxs;
  }

  zeros(depth) {
    switch (depth) {
      case 0:
        return 3188939322973067328877758594842858906904921945741806511873286077735470116993n;

      case 1:
        return 6720259710669087831553846354631287113196125544132777832360700859399112740325n;

      case 2:
        return 14100726739369462886368459740864540836886914118842810705097104616524114430129n;

      case 3:
        return 112209499692908591232643365395517544644201095981324526811343712736997538292n;

      case 4:
        return 11238702789989372205358809326740789974778677302212579882358701848401430529054n;

      case 5:
        return 21118991588408561550105584082907020832826967877110425744704869934925621375884n;

      case 6:
        return 13928999962669174009957618733358904138773364497211262075218273133701458245334n;

      case 7:
        return 4410551735910153119819573859955454436891526935489927768186920269199009086711n;

      case 8:
        return 6371417810032901106459001319976509422393802227599077240268135659361879889172n;

      case 9:
        return 18303252502178989282724107955784338429396339444109866555218963820384654853100n;

      case 10:
        return 21601136083806127453349072297093675845609337768023007472589896098272712879148n;

      case 11:
        return 3177991236287930977088471881249077121390896667382205526608404069808721782110n;

      case 12:
        return 177066845958820354320564460296287967210704690936203707166041222838155498441n;

      case 13:
        return 9465842901997161586211475891262324887429446592420095001945269146504125737375n;

      case 14:
        return 17517169362510974348713354507589007151377229122934210076589580727708001187024n;

      case 15:
        return 14114249794526233911977124067987027463854218809064337636917262250924458933577n;

      case 16:
        return 16502266580127892154129350749510264365381659669009091175992225177084196816663n;

      case 17:
        return 21651940120471144339632125267213162691248706081088182517944256595633071594285n;

      case 18:
        return 8110679893386297053688650854198064355080679239667629905853357633483952638077n;

      case 19:
        return 11322001787927580749986074460628292978498994207217486745890270787047102630867n;

      case 20:
        return 1963955578147471809555382774201803161676532308393993847841272436257385505086n;

      case 21:
        return 3185489383365160608195033429570703838049061463149081669697404594233395912923n;

      case 22:
        return 17272846034129620692113855472652233644682447619121320889463345587978723782440n;

      case 23:
        return 4765321745028962516538035357596636043464863555373511241437252535555066381216n;

      case 24:
        return 5658611457602422164595371390478562715873563150068767923466203189741106240631n;

      case 25:
        return 18418674407137299669994143839130723551204177072529239321344837367323128293169n;

      case 26:
        return 7885056461951207064242970099992932870331159884571482082326166927209100592966n;

      case 27:
        return 12278171883927291103430107511892900899846607490418231882738313648576091738545n;

      case 28:
        return 3247686091741635087172657301110027005428023730761977089020403026614827279990n;

      case 29:
        return 20798040694238808427824045066482787450513395569904336285703507121278901059107n;

      case 30:
        return 21469725865909319462397596271758230508985208099559437826093010906919046438348n;

      case 31:
        return 20840601845701666340258294923089698071181837734170489061237550134947360788510n;

      default:
        throw new Error("Depth is too high");
    }
  }
};
